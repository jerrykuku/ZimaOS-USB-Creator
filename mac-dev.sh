#!/bin/bash
# Quick development script: incremental build + run
# Usage: ./mac-dev.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
QT_VERSION_DEFAULT=$(sed -n 's/^QT_VERSION_DEFAULT="\([^"]*\)".*/\1/p' \
    "$SCRIPT_DIR/qt/qt-build-common.sh" | head -1)
QT_ROOT="${Qt6_ROOT:-/opt/Qt/${QT_VERSION_DEFAULT:-6.11.1}/macos}"
ARCH="$(uname -m)"
APP_NAME="ZimaOS USB Creator"
BUILD_TARGET="zimaos-usb-creator"
APP="$BUILD_DIR/$BUILD_TARGET.app/Contents/MacOS/zimaos-usb-creator"
APP_BUNDLE="$BUILD_DIR/$BUILD_TARGET.app"


# Parse command line arguments
RECONFIGURE=0
QML_LIVE=0
QML_WATCH=0
for arg in "$@"; do
    case $arg in
        --reconfigure)
            RECONFIGURE=1
            shift
            ;;
        --qt-root=*)
            QT_ROOT="${arg#*=}"
            RECONFIGURE=1
            shift
            ;;
        --arch=*)
            ARCH="${arg#*=}"
            RECONFIGURE=1
            shift
            ;;
        --qml-live)
            QML_LIVE=1
            shift
            ;;
        --watch)
            QML_LIVE=1
            QML_WATCH=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --reconfigure          Force CMake reconfiguration"
            echo "  --qt-root=PATH         Specify Qt installation path"
            echo "  --arch=ARCH            Build architecture (arm64, x86_64, or universal)"
            echo "  --qml-live             Load QML directly from src while retaining incremental C++ builds"
            echo "  --watch                Restart automatically when a QML file changes (implies --qml-live)"
            echo "  --help, -h             Show this help message"
            exit 0
            ;;
    esac
done

# Check if Ninja is installed
if ! command -v ninja >/dev/null 2>&1; then
    echo "❌ Error: Ninja build system not found"
    echo "Please install: brew install ninja"
    exit 1
fi

# Check if CMake reconfiguration is needed (using Ninja)
if [[ ! -f "$BUILD_DIR/build.ninja" ]] || [[ ! -f "$APP" ]] || [[ $RECONFIGURE -eq 1 ]]; then
    echo "🔧 Configuring Ninja build system..."
    BUILD_TYPE=Debug "$SCRIPT_DIR/mac-build-ninja.sh" --qt-root="$QT_ROOT" --arch="$ARCH" "$BUILD_TARGET"
else
    # Incremental build (only recompile changed files)
    echo "⏳ Incremental build..."
    START=$(date +%s)

    # Use ninja for incremental build
    if ninja -C "$BUILD_DIR" "$BUILD_TARGET" 2>&1 | tail -10; then
        END=$(date +%s)
        DURATION=$((END - START))
        echo "✅ Build completed (${DURATION}s)"
    else
        echo "❌ Build failed"
        exit 1
    fi
fi

# Check if application exists
if [[ ! -f "$APP" ]]; then
    echo "❌ Error: Application not found: $APP"
    echo "Searching for possible locations..."
    find "$BUILD_DIR" -name "zimaos-usb-creator" -type f 2>/dev/null || true
    exit 1
fi

echo "🚀 Launching: $APP_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $QML_LIVE -eq 1 ]]; then
    echo "⚡ Loading QML directly from $SCRIPT_DIR/src"
    echo "🔏 Signing development app bundle..."
    codesign --force --deep --sign - "$APP_BUNDLE"
    if [[ $QML_WATCH -eq 0 ]]; then
        exec env RPI_IMAGER_QML_SOURCE_DIR="$SCRIPT_DIR/src" "$APP"
    fi
    echo "Watching QML files under $SCRIPT_DIR/src (Ctrl+C to stop)"
    WATCH_PID=""
    stop_watched_app() {
        [[ -n "$WATCH_PID" ]] && kill -TERM "$WATCH_PID" 2>/dev/null || true
        [[ -n "$WATCH_PID" ]] && wait "$WATCH_PID" 2>/dev/null || true
    }
    trap 'stop_watched_app; exit 130' INT TERM
    WATCH_SIGNATURE=""
    while true; do
        WATCH_SIGNATURE="$(find "$SCRIPT_DIR/src" -type f -name '*.qml' -exec stat -f '%m %N' {} + 2>/dev/null | sort)"
        env RPI_IMAGER_QML_SOURCE_DIR="$SCRIPT_DIR/src" "$APP" &
        WATCH_PID=$!
        while kill -0 "$WATCH_PID" 2>/dev/null; do
            sleep 1
            NEW_SIGNATURE="$(find "$SCRIPT_DIR/src" -type f -name '*.qml' -exec stat -f '%m %N' {} + 2>/dev/null | sort)"
            if [[ "$NEW_SIGNATURE" != "$WATCH_SIGNATURE" ]]; then
                echo "QML changed; restarting application..."
                kill -TERM "$WATCH_PID" 2>/dev/null || true
                break
            fi
        done
        wait "$WATCH_PID" 2>/dev/null || true
        WATCH_PID=""
        [[ "$NEW_SIGNATURE" != "$WATCH_SIGNATURE" ]] || break
        sleep 0.2
    done
    exit 0
fi

exec "$APP"
