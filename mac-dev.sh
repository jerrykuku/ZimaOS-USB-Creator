#!/bin/bash
# Quick development script: incremental build + run
# Usage: ./mac-dev.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
QT_ROOT="${Qt6_ROOT:-/opt/Qt/6.9.3/macos}"
APP_NAME="ZimaOS USB Creator"
BUILD_TARGET="zimaos-usb-creator"
APP="$BUILD_DIR/$BUILD_TARGET.app/Contents/MacOS/zimaos-usb-creator"
APP_BUNDLE="$BUILD_DIR/$BUILD_TARGET.app"


# Parse command line arguments
RECONFIGURE=0
QML_LIVE=0
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
        --qml-live)
            QML_LIVE=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --reconfigure          Force CMake reconfiguration"
            echo "  --qt-root=PATH         Specify Qt installation path"
            echo "  --qml-live             Load QML directly from src and skip rebuilding when possible"
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
    "$SCRIPT_DIR/mac-build-ninja.sh" --qt-root="$QT_ROOT" "$BUILD_TARGET"
elif [[ $QML_LIVE -eq 0 ]]; then
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
    exec env RPI_IMAGER_QML_SOURCE_DIR="$SCRIPT_DIR/src" "$APP"
fi

exec "$APP"
