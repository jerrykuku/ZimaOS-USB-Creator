#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Build script using Ninja for faster compilation
# Supports both Linux and macOS platforms

# Parse command line arguments
if [ "$(uname -s)" = "Darwin" ]; then
    ARCH="universal"
else
    ARCH=$(uname -m)
fi
CLEAN_BUILD=0     # Don't clean by default for faster rebuilds
QT_ROOT_ARG=""
SIGNING_IDENTITY=""
NOTARIZE_KEYCHAIN_PROFILE=""
BUILD_TARGET=""   # Optional build target (e.g., zimaos-usb-creator)

usage() {
    echo "Usage: $0 [options] [target]"
    echo "Options:"
    echo "  --arch=ARCH                    Target architecture (x86_64, aarch64, arm64)"
    echo "  --qt-root=PATH                 Path to Qt installation directory"
    echo "  --clean                        Clean build directory before building"
    echo "  --signing-identity=CN          Developer ID Certificate Common Name (macOS)"
    echo "  --notarize-profile=PROFILE     Keychain profile for notarization (macOS)"
    echo "  -h, --help                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Build with default settings"
    echo "  $0 --clean                                   # Clean build"
    echo "  $0 --qt-root=/opt/Qt/6.11.1/macos            # Specify Qt path"
    echo "  $0 --signing-identity=\"Developer ID\"       # Enable code signing (macOS)"
    echo "  $0 zimaos-usb-creator                        # Build specific target"
    exit 1
}

for arg in "$@"; do
    case $arg in
        --arch=*)
            ARCH="${arg#*=}"
            shift
            ;;
        --qt-root=*)
            QT_ROOT_ARG="${arg#*=}"
            shift
            ;;
        --clean)
            CLEAN_BUILD=1
            shift
            ;;
        --signing-identity=*)
            SIGNING_IDENTITY="${arg#*=}"
            shift
            ;;
        --notarize-profile=*)
            NOTARIZE_KEYCHAIN_PROFILE="${arg#*=}"
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $arg"
            usage
            ;;
        *)
            # Only treat as build target if it doesn't look like part of a previous option
            if [ -z "$BUILD_TARGET" ]; then
                BUILD_TARGET="$arg"
            fi
            shift
            ;;
    esac
done

# Resolve Qt root path argument if provided (expand ~ and convert to absolute path)
if [ -n "$QT_ROOT_ARG" ]; then
    # Expand tilde if present at the start
    case "$QT_ROOT_ARG" in
        "~"/*) QT_ROOT_ARG="$HOME/${QT_ROOT_ARG#\~/}" ;;
        "~")   QT_ROOT_ARG="$HOME" ;;
    esac
    # Convert to absolute path if it exists
    if [ -e "$QT_ROOT_ARG" ]; then
        QT_ROOT_ARG=$(cd "$QT_ROOT_ARG" && pwd)
    else
        echo "Warning: Specified Qt root path does not exist: $QT_ROOT_ARG"
        echo "Will attempt to use it anyway, but this may fail..."
    fi
fi

# Normalize architecture names (arm64 -> aarch64 on Linux)
if [ "$ARCH" = "arm64" ] && [ "$(uname -s)" != "Darwin" ]; then
    ARCH="aarch64"
fi

echo "Building for architecture: $ARCH"
echo "Platform: $(uname -s)"

# Extract project information from CMakeLists.txt
SOURCE_DIR="src/"
CMAKE_FILE="${SOURCE_DIR}CMakeLists.txt"

# Use the nearest release tag for distributable builds. This keeps local
# uncommitted changes and post-tag commit counts out of the app/DMG version.
GIT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || git describe --tags --always 2>/dev/null || echo "0.0.0-unknown")
# Normalize repository tag conventions to SemVer for the packaged app. A
# four-part hotfix tag such as v2.0.11.1 becomes valid build metadata.
GIT_VERSION=$(printf '%s' "$GIT_VERSION" | sed -E \
    -e 's/^v([0-9]+\.[0-9]+\.[0-9]+)\.([0-9]+)$/\1+hotfix.\2/' \
    -e 's/^v([0-9].*)$/\1/')

# Extract numeric version components
MAJOR=$(echo "$GIT_VERSION" | sed -n 's/^v\{0,1\}\([0-9]\{1,\}\)\.[0-9]\{1,\}\.[0-9]\{1,\}.*/\1/p')
MINOR=$(echo "$GIT_VERSION" | sed -n 's/^v\{0,1\}[0-9]\{1,\}\.\([0-9]\{1,\}\)\.[0-9]\{1,\}.*/\1/p')
PATCH=$(echo "$GIT_VERSION" | sed -n 's/^v\{0,1\}[0-9]\{1,\}\.[0-9]\{1,\}\.\([0-9]\{1,\}\).*/\1/p')

if [ -n "$MAJOR" ] && [ -n "$MINOR" ] && [ -n "$PATCH" ]; then
    PROJECT_VERSION="$MAJOR.$MINOR.$PATCH"
else
    MAJOR="0"
    MINOR="0"
    PATCH="0"
    PROJECT_VERSION="0.0.0"
    echo "Warning: Could not parse version from git tag: $GIT_VERSION"
fi

# Extract project name
PROJECT_NAME=$(grep "project(" "$CMAKE_FILE" | head -1 | sed 's/project(\([^[:space:]]*\).*/\1/' | tr '[:upper:]' '[:lower:]')

echo "Building $PROJECT_NAME version $GIT_VERSION (numeric: $PROJECT_VERSION)"

# Check for Qt installation
# Priority: 1. Command line argument, 2. Environment variable, 3. Auto-detection
QT_VERSION=""
QT_DIR=""

# Check if Qt root is specified via command line argument (highest priority)
if [ -n "$QT_ROOT_ARG" ]; then
    echo "Using Qt from command line argument: $QT_ROOT_ARG"
    QT_DIR="$QT_ROOT_ARG"
# Check if Qt6_ROOT is explicitly set in environment
elif [ -n "$Qt6_ROOT" ]; then
    echo "Using Qt from Qt6_ROOT environment variable: $Qt6_ROOT"
    QT_DIR="$Qt6_ROOT"
# Auto-detect Qt installation
else
    if [ "$(uname -s)" = "Darwin" ]; then
        # macOS: Check /opt/Qt
        if [ -d "/opt/Qt" ]; then
            echo "Checking for Qt installations in /opt/Qt..."
            NEWEST_QT=$(find /opt/Qt -maxdepth 1 -type d -name "6.*" |
                sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
            if [ -n "$NEWEST_QT" ]; then
                QT_VERSION=$(basename "$NEWEST_QT")
                if [ -d "$NEWEST_QT/macos" ]; then
                    QT_DIR="$NEWEST_QT/macos"
                    echo "Found Qt $QT_VERSION for macOS at $QT_DIR"
                fi
            fi
        fi
    else
        # Linux: Check /opt/Qt
        if [ -d "/opt/Qt" ]; then
            echo "Checking for Qt installations in /opt/Qt..."
            NEWEST_QT=$(find /opt/Qt -maxdepth 1 -type d -name "6.*" |
                sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
            if [ -n "$NEWEST_QT" ]; then
                QT_VERSION=$(basename "$NEWEST_QT")

                # Find appropriate compiler directory for the architecture
                if [ "$ARCH" = "x86_64" ]; then
                    if [ -d "$NEWEST_QT/gcc_64" ]; then
                        QT_DIR="$NEWEST_QT/gcc_64"
                    fi
                elif [ "$ARCH" = "aarch64" ]; then
                    if [ -d "$NEWEST_QT/gcc_arm64" ]; then
                        QT_DIR="$NEWEST_QT/gcc_arm64"
                    fi
                fi

                if [ -n "$QT_DIR" ]; then
                    echo "Found Qt $QT_VERSION for $ARCH at $QT_DIR"
                else
                    echo "Found Qt $QT_VERSION, but no binary directory for $ARCH"
                    QT_VERSION=""
                fi
            fi
        fi
    fi
fi

# Try to determine Qt version if not already set
if [ -n "$QT_DIR" ] && [ -z "$QT_VERSION" ]; then
    if [ -f "$QT_DIR/bin/qmake" ]; then
        QT_VERSION=$("$QT_DIR/bin/qmake" -query QT_VERSION)
        echo "Qt version: $QT_VERSION"
    fi
fi

# If Qt not found, show error and suggestions
if [ -z "$QT_DIR" ]; then
    echo "Error: No suitable Qt installation found for $ARCH"

    if [ -f "./qt/build-qt.sh" ]; then
        echo "You can build Qt using the provided script:"
        echo "  ./qt/build-qt-macos.sh"
        echo "Or specify the Qt location with:"
        echo "  $0 --qt-root=/path/to/qt"
    else
        echo "You can specify the Qt location with:"
        echo "  $0 --qt-root=/path/to/qt"
        echo "  export Qt6_ROOT=/path/to/qt"
    fi

    exit 1
fi

# Check if Ninja is installed
if ! command -v ninja >/dev/null 2>&1; then
    echo "Error: Ninja build system not found"
    echo "Please install Ninja:"
    if [ "$(uname -s)" = "Darwin" ]; then
        echo "  brew install ninja"
    else
        echo "  sudo apt-get install ninja-build  # Debian/Ubuntu"
        echo "  sudo dnf install ninja-build      # Fedora/RHEL"
    fi
    exit 1
fi

# Configuration
BUILD_TYPE="${BUILD_TYPE:-MinSizeRel}"  # Optimize for size unless overridden (dev uses Debug)

# Set up build directory
BUILD_DIR="build"

# Clean up previous builds if requested
if [ "$CLEAN_BUILD" -eq 1 ]; then
    echo "Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

echo "Configuring build with Ninja..."
cd "$BUILD_DIR"

# Set architecture-specific CMake flags
CMAKE_EXTRA_FLAGS=""
if [ "$ARCH" = "aarch64" ] && [ "$(uname -m)" = "x86_64" ]; then
    # Cross-compiling from x86_64 to aarch64
    echo "Cross-compiling from $(uname -m) to $ARCH"
    CMAKE_EXTRA_FLAGS="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64"
fi

# Add Qt path to CMake flags
CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DQt6_ROOT=$QT_DIR"

# Add macOS-specific build options if on macOS
if [ "$(uname -s)" = "Darwin" ]; then
    echo "Configuring for macOS build..."

    # Keep the existing universal default on macOS, while allowing smaller
    # single-architecture bundles for distribution.
    case "$ARCH" in
        universal)
            MACOS_ARCHES="arm64;x86_64"
            ;;
        arm64|x86_64)
            MACOS_ARCHES="$ARCH"
            ;;
        *)
            echo "Unsupported macOS architecture: $ARCH (use arm64, x86_64, or universal)"
            exit 1
            ;;
    esac
    CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DCMAKE_OSX_ARCHITECTURES=$MACOS_ARCHES"
    echo "macOS architectures: $MACOS_ARCHES"

    # Code signing (optional - only if SIGNING_IDENTITY is set)
    if [ -n "$SIGNING_IDENTITY" ]; then
        CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DIMAGER_SIGNED_APP=ON"
        CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DIMAGER_SIGNING_IDENTITY=$SIGNING_IDENTITY"
        echo "Code signing enabled with identity: $SIGNING_IDENTITY"
    fi

    # Notarization (optional - only if NOTARIZE_KEYCHAIN_PROFILE is set)
    if [ -n "$NOTARIZE_KEYCHAIN_PROFILE" ]; then
        CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DIMAGER_NOTARIZE_APP=ON"
        CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DIMAGER_NOTARIZE_KEYCHAIN_PROFILE=$NOTARIZE_KEYCHAIN_PROFILE"
        echo "Notarization enabled with keychain profile: $NOTARIZE_KEYCHAIN_PROFILE"
    fi
fi

# Configure with Ninja generator
# shellcheck disable=SC2086
cmake "../$SOURCE_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    $CMAKE_EXTRA_FLAGS

# Build with Ninja
echo "Building with Ninja..."
if [ -n "$BUILD_TARGET" ]; then
    echo "Building target: $BUILD_TARGET"
    ninja "$BUILD_TARGET"
else
    ninja
fi

cd ..

echo ""
echo "Build completed successfully!"
echo "Build directory: $BUILD_DIR"

# Show output location based on platform
if [ "$(uname -s)" = "Darwin" ]; then
    if [ -f "$BUILD_DIR/ZimaOS USB Creator-$PROJECT_VERSION.dmg" ]; then
        echo "DMG file: $BUILD_DIR/ZimaOS USB Creator-$PROJECT_VERSION.dmg"
    elif [ -d "$BUILD_DIR/ZimaOS USB Creator.app" ]; then
        echo "Application bundle: $BUILD_DIR/ZimaOS USB Creator.app"
    fi
else
    if [ -f "$BUILD_DIR/zimaos-usb-creator" ]; then
        echo "Binary: $BUILD_DIR/zimaos-usb-creator"
    fi
fi
