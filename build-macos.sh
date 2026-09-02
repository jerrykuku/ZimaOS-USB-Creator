#!/bin/bash
# Unified macOS build channel for ZimaOS USB Creator.
#
# Usage: ./build-macos.sh <install|dev|build|release|clean> [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QT_VERSION="$(sed -n 's/^QT_VERSION_DEFAULT="\([^"]*\)".*/\1/p' "$SCRIPT_DIR/qt/qt-build-common.sh" | head -1)"
QT_VERSION="${QT_VERSION:-6.11.1}"
if [ -n "${Qt6_ROOT:-}" ]; then
    QT_ROOT="$Qt6_ROOT"
elif [ -d "/opt/Qt/$QT_VERSION/macos" ]; then
    QT_ROOT="/opt/Qt/$QT_VERSION/macos"
else
    QT_ROOT="$HOME/Qt/$QT_VERSION/macos"
fi
ARCH="$(uname -m)"
SIGNING_IDENTITY=""
NOTARIZE_PROFILE=""
WITH_QT=0
QT_VERBOSE=0
QT_ROOT_EXPLICIT=0
QML_LIVE=1
QML_WATCH=1

usage() {
    cat <<EOF
Usage: $0 <install|dev|build|release|clean> [options]

Actions:
  install       Install Homebrew tools; use --with-qt to build the Qt toolchain
  dev           Build for the host architecture and launch with QML auto-reload
  build         Build an unsigned DMG
  release       Build a signed DMG (optionally notarized)
  clean         Remove the macOS build directory

Options:
  --arch=ARCH                    arm64, x86_64, or universal (default: $ARCH)
  --qt-root=PATH                 Qt installation root
  --signing-identity=IDENTITY    Developer ID Application identity (release)
  --notarize-profile=PROFILE     notarytool keychain profile (release)
  --with-qt                      Build the pinned Qt toolchain during install
  --qml-live                     Load QML directly from src for live UI iteration (dev; default)
  --watch                        Restart the QML live app when source files change (dev; default)
  --verbose                      Show verbose Qt configure and build commands
  -h, --help                     Show this help
EOF
}

die() { echo "build-macos: $*" >&2; exit 1; }
need_macos() { [ "$(uname -s)" = Darwin ] || die "this channel must run on macOS"; }
have() { command -v "$1" >/dev/null 2>&1; }
step() { printf '\n[%s] build-macos: %s\n' "$(date '+%H:%M:%S')" "$*"; }

run_qt_build() {
    local log_file qt_prefix qt_pid qt_status
    log_file="${TMPDIR:-/tmp}/zimaos-usb-creator-qt-${QT_VERSION}-$(date '+%Y%m%d-%H%M%S').log"
    step "3/3 Building Qt $QT_VERSION; live output is also saved to $log_file"

    if [ "$QT_ROOT_EXPLICIT" -eq 1 ] && [[ "$QT_ROOT" == */macos ]]; then
        qt_prefix="${QT_ROOT%/macos}"
    elif [ "$QT_ROOT_EXPLICIT" -eq 1 ]; then
        qt_prefix="$QT_ROOT"
    else
        qt_prefix="$HOME/Qt/$QT_VERSION"
    fi
    qt_args=(--version="$QT_VERSION" --prefix="$qt_prefix" --unprivileged --no-universal)
    [ "$QT_VERBOSE" -eq 1 ] && qt_args+=(--verbose)

    # Keep the pipeline asynchronous so Ctrl+C can terminate both the Qt
    # wrapper and the tee process while preserving live output.
    terminate_qt_build() {
        pkill -TERM -P "$qt_pid" 2>/dev/null || true
        kill -TERM "$qt_pid" 2>/dev/null || true
    }
    set +e
    (sh "$SCRIPT_DIR/qt/build-qt-macos.sh" "${qt_args[@]}" 2>&1 | tee "$log_file") &
    qt_pid=$!
    trap 'terminate_qt_build; exit 130' INT TERM
    wait "$qt_pid"
    qt_status=$?
    trap - INT TERM
    set -e
    [ "$qt_status" -eq 0 ] || return "$qt_status"
    QT_ROOT="$qt_prefix/macos"
    step "Qt $QT_VERSION is ready at $QT_ROOT"
}

install_tools() {
    need_macos
    step "1/3 Checking Xcode Command Line Tools and Homebrew"
    have brew || die "Homebrew is required: https://brew.sh"
    xcode-select -p >/dev/null 2>&1 || die "install Xcode Command Line Tools with: xcode-select --install"

    step "2/3 Checking Homebrew build tools"
    local packages=()
    for tool in cmake ninja create-dmg; do
        brew list --formula "$tool" >/dev/null 2>&1 || packages+=("$tool")
    done
    if [ "${#packages[@]}" -gt 0 ]; then
        echo "build-macos: installing ${packages[*]}"
        brew install "${packages[@]}"
    else
        echo "build-macos: cmake, ninja, and create-dmg are already installed"
    fi
    if [ "$WITH_QT" -eq 1 ] || [ ! -x "$QT_ROOT/bin/qmake" ]; then
        run_qt_build
    else
        step "3/3 Qt found at $QT_ROOT; nothing else to install"
    fi
}

parse_options() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        usage
        exit 0
    fi
    ACTION="${1:-}"; [ -n "$ACTION" ] || { usage; exit 1; }; shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --arch=*) ARCH="${1#*=}" ;;
            --qt-root=*) QT_ROOT="${1#*=}"; QT_ROOT_EXPLICIT=1 ;;
            --signing-identity=*) SIGNING_IDENTITY="${1#*=}" ;;
            --notarize-profile=*) NOTARIZE_PROFILE="${1#*=}" ;;
            --with-qt) WITH_QT=1 ;;
            --qml-live) QML_LIVE=1 ;;
            --watch) QML_LIVE=1; QML_WATCH=1 ;;
            --verbose) QT_VERBOSE=1 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown option: $1" ;;
        esac
        shift
    done
}

parse_options "$@"
need_macos

case "$ACTION" in
    install)
        install_tools
        ;;
    clean)
        rm -rf "$SCRIPT_DIR/build"
        echo "build-macos: removed $SCRIPT_DIR/build"
        ;;
    dev)
        have cmake || die "cmake is missing; run '$0 install'"
        have ninja || die "ninja is missing; run '$0 install'"
        [ -x "$QT_ROOT/bin/qmake" ] || die "Qt is missing at $QT_ROOT; run '$0 install --with-qt' or pass --qt-root"
        args=(--qt-root="$QT_ROOT" --arch="$ARCH")
        if [ "$QML_LIVE" -eq 0 ]; then
            args+=(--reconfigure)
        else
            args+=(--qml-live)
            [ "$QML_WATCH" -eq 1 ] && args+=(--watch)
        fi
        "$SCRIPT_DIR/mac-dev.sh" "${args[@]}"
        ;;
    build)
        have ninja || die "ninja is missing; run '$0 install'"
        "$SCRIPT_DIR/mac-build-dmg.sh" --arch="$ARCH" --qt-root="$QT_ROOT"
        ;;
    release)
        [ -n "$SIGNING_IDENTITY" ] || die "release requires --signing-identity=..."
        have codesign || die "codesign is missing; install Xcode Command Line Tools"
        security find-identity -v -p codesigning | grep -Fq "$SIGNING_IDENTITY" || \
            die "signing identity not found: $SIGNING_IDENTITY"
        args=(--clean --arch="$ARCH" --qt-root="$QT_ROOT" --signing-identity="$SIGNING_IDENTITY")
        [ -n "$NOTARIZE_PROFILE" ] && args+=(--notarize-profile="$NOTARIZE_PROFILE")
        "$SCRIPT_DIR/mac-build-dmg.sh" "${args[@]}"
        ;;
    *) die "unknown action '$ACTION' (use install, dev, build, release, or clean)" ;;
esac
