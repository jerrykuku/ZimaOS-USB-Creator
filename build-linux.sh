#!/bin/sh
# Unified Linux build channel for ZimaOS USB Creator.
#
# Usage: ./build-linux.sh <install|dev|build|release|clean> [options]
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
BUILD_DIR=${BUILD_DIR:-$SCRIPT_DIR/build-linux}
QT_ROOT=${Qt6_ROOT:-${QT6_ROOT:-}}
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
JOBS=${JOBS:-}
CLI=0
WITH_QT=0
RELEASE_TARGET=repo
SIGNING_KEY=${DEB_SIGNING_KEY:-}
DPUT_HOST_ARG=${DPUT_HOST:-}

if [ -z "$QT_ROOT" ]; then
    QT_VERSION=$(sed -n 's/^QT_VERSION_DEFAULT="\([^"]*\)".*/\1/p' "$SCRIPT_DIR/qt/qt-build-common.sh" | head -1)
    QT_VERSION=${QT_VERSION:-6.11.1}
    case "$ARCH" in
        amd64|x86_64) QT_VARIANT=gcc_64 ;;
        arm64|aarch64) QT_VARIANT=gcc_arm64 ;;
        armhf|armv7l|armv6l) QT_VARIANT=gcc_arm32 ;;
        *) QT_VARIANT= ;;
    esac
    if [ -n "$QT_VARIANT" ]; then
        for candidate in "/opt/Qt/$QT_VERSION/$QT_VARIANT" "$HOME/Qt/$QT_VERSION/$QT_VARIANT"; do
            if [ -x "$candidate/bin/qmake" ]; then
                QT_ROOT=$candidate
                break
            fi
        done
    fi
fi

usage() {
    cat <<EOF
Usage: $0 <install|dev|build|release|clean> [options]

Actions:
  install       Install Debian/Ubuntu build and packaging dependencies
  dev           Debug CMake/Ninja build (add --run to launch it)
  build         MinSizeRel CMake/Ninja build
  release       Debian/AppImage release; default target is repo
  clean         Remove the Linux build directory

Options:
  --arch=ARCH                    amd64, arm64, or armhf (release target)
  --build-dir=PATH               CMake build directory (dev/build)
  --qt-root=PATH                 Qt 6 installation root
  --jobs=N                       Parallel build jobs
  --cli                          Build CLI-only target for dev/build
  --run                          Launch the dev binary after building
  --with-qt                      Build the pinned Linux Qt toolchain on install
  --target=TARGET                release target: repo, arch, appimages, binary,
                                 embedded, or source
  --signing-key=KEY              GPG key ID for Debian release signing
  --dput-host=HOST               Upload signed .changes with dput
  --unsigned                     Permit an unsigned release (explicit override)
  -h, --help                     Show this help
EOF
}

die() { echo "build-linux: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

parse_options() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        usage
        exit 0
    fi
    ACTION=${1:-}; [ -n "$ACTION" ] || { usage; exit 1; }; shift || true
    RUN=0; UNSIGNED=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --arch=*) ARCH=${1#*=} ;;
            --build-dir=*) BUILD_DIR=${1#*=} ;;
            --qt-root=*) QT_ROOT=${1#*=} ;;
            --jobs=*) JOBS=${1#*=} ;;
            --cli) CLI=1 ;;
            --run) RUN=1 ;;
            --with-qt) WITH_QT=1 ;;
            --target=*) RELEASE_TARGET=${1#*=} ;;
            --signing-key=*) SIGNING_KEY=${1#*=} ;;
            --dput-host=*) DPUT_HOST_ARG=${1#*=} ;;
            --unsigned) UNSIGNED=1 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown option: $1" ;;
        esac
        shift
    done
}

parse_options "$@"
[ "$(uname -s)" = Linux ] || die "this channel must run on Linux"

install_tools() {
    [ -f /etc/debian_version ] || die "install currently supports Debian/Ubuntu hosts"
    have apt-get || die "apt-get is required"
    APT=apt-get
    [ "$(id -u)" -eq 0 ] || { have sudo || die "run as root or install sudo"; APT="sudo apt-get"; }
    # shellcheck disable=SC2086
    $APT update
    # shellcheck disable=SC2086
    $APT install -y --no-install-recommends \
        build-essential cmake ninja-build git curl file xz-utils pkg-config \
        libgnutls28-dev mmdebstrap qemu-user-static binfmt-support \
        dpkg-dev debhelper devscripts dput
    if [ "$WITH_QT" -eq 1 ]; then
        QT_VERSION=$(sed -n 's/^QT_VERSION_DEFAULT="\([^"]*\)".*/\1/p' "$SCRIPT_DIR/qt/qt-build-common.sh" | head -1)
        QT_VERSION=${QT_VERSION:-6.11.1}
        sh "$SCRIPT_DIR/qt/build-qt.sh" --version="$QT_VERSION" \
            --prefix="$HOME/Qt/$QT_VERSION" --unprivileged
    fi
}

cmake_build() {
    have cmake || die "cmake is missing; run '$0 install'"
    have ninja || die "ninja is missing; run '$0 install'"
    [ -n "$JOBS" ] || JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
    set -- -S "$SCRIPT_DIR/src" -B "$BUILD_DIR" -G Ninja "-DCMAKE_BUILD_TYPE=$1"
    [ -n "$QT_ROOT" ] && set -- "$@" "-DQt6_ROOT=$QT_ROOT"
    [ "$CLI" -eq 1 ] && set -- "$@" -DBUILD_CLI_ONLY=ON
    cmake "$@"
    target=zimaos-usb-creator
    [ "$CLI" -eq 1 ] && target=zimaos-usb-creator-cli
    cmake --build "$BUILD_DIR" --parallel "$JOBS" --target "$target"
    echo "build-linux: artifact $BUILD_DIR/$target"
    if [ "$RUN" -eq 1 ]; then
        exec "$BUILD_DIR/$target"
    fi
}

release_sign_and_upload() {
    [ "$UNSIGNED" -eq 1 ] || [ -n "$SIGNING_KEY" ] || \
        die "release requires --signing-key=KEY (or explicitly pass --unsigned)"
    if [ "$UNSIGNED" -eq 0 ]; then
        have debsign || die "debsign is missing; run '$0 install'"
        for changes in "$SCRIPT_DIR"/out/debian/*.changes; do
            [ -f "$changes" ] || continue
            debsign --re-sign -k"$SIGNING_KEY" "$changes"
        done
    fi
    if [ -n "$DPUT_HOST_ARG" ]; then
        have dput || die "dput is missing; run '$0 install'"
        for changes in "$SCRIPT_DIR"/out/debian/*.changes; do
            [ -f "$changes" ] || continue
            dput "$DPUT_HOST_ARG" "$changes"
        done
    fi
}

case "$ACTION" in
    install) install_tools ;;
    clean) rm -rf "$BUILD_DIR"; echo "build-linux: removed $BUILD_DIR" ;;
    dev) cmake_build Debug ;;
    build) cmake_build MinSizeRel ;;
    release)
        if [ "$UNSIGNED" -eq 0 ]; then
            have debsign || die "debsign is missing; run '$0 install'"
            [ -n "$SIGNING_KEY" ] || die "release requires --signing-key=KEY (or explicitly pass --unsigned)"
            have gpg || die "gpg is missing; run '$0 install'"
            gpg --list-secret-keys "$SIGNING_KEY" >/dev/null 2>&1 || die "GPG secret key not found: $SIGNING_KEY"
        fi
        if [ -n "$DPUT_HOST_ARG" ]; then
            have dput || die "dput is missing; run '$0 install'"
        fi
        case "$RELEASE_TARGET" in
            repo) DPUT_HOST= "$SCRIPT_DIR/debian/release.sh" repo ;;
            arch) [ -n "$ARCH" ] || die "--arch is required for --target=arch"; "$SCRIPT_DIR/debian/release.sh" arch "$ARCH" ;;
            appimages|binary|embedded) [ -n "$ARCH" ] || die "--arch is required for --target=$RELEASE_TARGET"; "$SCRIPT_DIR/debian/release.sh" "$RELEASE_TARGET" "$ARCH" ;;
            source) "$SCRIPT_DIR/debian/release.sh" source ;;
            *) die "unknown release target: $RELEASE_TARGET" ;;
        esac
        release_sign_and_upload
        ;;
    *) die "unknown action '$ACTION' (use install, dev, build, release, or clean)" ;;
esac
