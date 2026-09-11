# Build Channels

This repository has three platform build channels. The platform channel is the
entry point a developer or release operator should use. Scripts listed under
"Auxiliary" are implementation stages and should normally not be invoked on
their own.

## Quick Map

| Platform | Development | Release artifact | Main output |
| --- | --- | --- | --- |
| macOS | `build-macos.sh dev` | `build-macos.sh release` | `.app` / `.dmg` |
| Windows | `build-windows.ps1 dev` | `build-windows.ps1 release` | `.exe` / installer |
| Linux | `build-linux.sh dev` | `build-linux.sh release` | AppImage / `.deb` |

Each platform has one public entry script. The four lifecycle actions are kept
consistent: `install` prepares tools and optional Qt, `dev` builds a debug
binary, `build` creates an unsigned distributable build, and `release` enables
the platform signing/publishing steps. `clean` is available as a maintenance
action on all three channels.

### Script lifecycle

The following status is intentional:

| Status | Scripts | Rule |
| --- | --- | --- |
| Public entry | `build-macos.sh`, `build-windows.ps1`, `build-linux.sh` | Start every platform build here. |
| Internal stage | `mac-dev.sh`, `mac-build-ninja.sh`, `mac-build-dmg.sh`, `create-appimage*.sh`, `create-embedded.sh`, and scripts under `debian/` | Called by a public entry or another pipeline stage; do not use as a separate channel. |
| Auxiliary tool | Qt build scripts, `setup-notarization.sh`, icon and embedded test scripts | Used only when preparing a toolchain, credentials, assets, or tests. |
| Manual maintenance | `src/mac/check_dependencies.sh`, `src/mac/create_simple_background.sh`, `src/windows/regenerate_icons.sh` | No production pipeline calls these; use only for manual asset/dependency maintenance. |

Legacy scripts are not part of the supported interface. They can be removed in
a later cleanup once downstream automation has migrated to the three public
entry scripts.

The application target is `zimaos-usb-creator`. The CLI variant uses the same
CMake project with `-DBUILD_CLI_ONLY=ON` and produces
`zimaos-usb-creator-cli`. Do not use the historical `rpi-imager` target names
in new commands.

## 1. macOS

### Prerequisites

```sh
xcode-select --install
brew install cmake ninja create-dmg
```

`create-dmg` is needed for signed/styled DMGs. The optional Qt source build is:

```sh
./qt/build-qt-macos.sh --unprivileged --no-universal \
  --prefix="$HOME/Qt/6.11.1"
```

The script appends `/macos`, so the resulting Qt root is
`$HOME/Qt/6.11.1/macos`. The pinned version is defined by
`QT_VERSION_DEFAULT` in [qt/qt-build-common.sh](qt/qt-build-common.sh).

### Development

Install dependencies and run an incremental debug build from the repository root:

```sh
./build-macos.sh install --with-qt
./build-macos.sh dev --qt-root="$HOME/Qt/6.11.1/macos"
```

The install command reports each Xcode/Homebrew/Qt stage with a timestamp.
Qt's live build output is also saved under `/tmp/zimaos-usb-creator-qt-*.log`.

The app is written to `build/zimaos-usb-creator.app`.

### Release DMG

Unsigned:

```sh
./build-macos.sh build --arch="$(uname -m)" \
  --qt-root="$HOME/Qt/6.11.1/macos"
```

Signed and optionally notarized:

```sh
./setup-notarization.sh                 # once, if notarization is needed
./build-macos.sh release --arch="$(uname -m)" \
  --qt-root="$HOME/Qt/6.11.1/macos" \
  --signing-identity="Developer ID Application: Your Name (TEAMID)" \
  --notarize-profile=zimaos-notarytool
```

Use `--arch=universal` only when the Qt installation and dependencies are
available for both `arm64` and `x86_64`.

The root-level `BUILD-NINJA.md` is retained only as a migration note; it is not
part of the macOS channel.

## 2. Windows

Windows uses the CMake project directly through a PowerShell entry point. The
script can install the Qt SDK and matching MinGW toolchain non-interactively with
`aqtinstall` (Python 3 is required), or you can install Qt manually with the
official Qt Online Installer. In either case, select the MinGW 64-bit kit and
make sure the paths passed to the build match the installed directories.

Automated installation:

```powershell
.\build-windows.ps1 install -WithQt
.\build-windows.ps1 dev -QtRoot "$env:LOCALAPPDATA\Qt\6.10.3\mingw_64" -MingwRoot "$env:LOCALAPPDATA\Qt\Tools\mingw1310_64"
.\build-windows.ps1 build
```

Like the macOS development channel, `dev` launches the completed debug app.
Pass `-NoRun` when you only need to build it (for example, in CI).
The manually launchable executable is `build-windows\deploy\zimaos-usb-creator.exe`:
`windeployqt` places it there together with `Qt6Network.dll` and the other Qt
runtime files. The same-named executable directly under `build-windows\` is the
raw build output and is not self-contained.

The default aqt version is `6.10.3` with the `win64_mingw` kit. The SDK is
installed under `%LOCALAPPDATA%\Qt` by default so a normal PowerShell session
can write it. Override the destination with `-QtInstallRoot` (or set
`QT_INSTALL_ROOT`) when a different writable location is required. Override
the Qt version when a different Qt 6 version is available or required:

```powershell
.\build-windows.ps1 install -WithQt -QtVersion 6.11.0 -QtArch win64_mingw
```

Before changing the defaults, check the versions and kits exposed by aqt:

```powershell
py -m aqt list-qt windows desktop
py -m aqt list-tool windows desktop
```

Manual installation with the official Qt Online Installer is also supported:
install Qt 6.9 or newer with `win64_mingw`, install the corresponding MinGW
tools, then pass the resulting `-QtRoot` and `-MingwRoot` paths to this script.
For example:

```powershell
.\build-windows.ps1 dev `
  -QtRoot "$env:LOCALAPPDATA\Qt\6.10.3\mingw_64" `
  -MingwRoot "$env:LOCALAPPDATA\Qt\Tools\mingw1310_64"
```

For a distributable signed installer, run `release` from a Developer PowerShell.
It enables `ENABLE_INNO_INSTALLER` and `IMAGER_SIGNED_APP`, checks for a
code-signing certificate and `signtool`, and builds the `inno_installer` target:

If Inno Setup is not installed, `release` installs it automatically through
`winget` (the Microsoft App Installer must be available).

```powershell
.\build-windows.ps1 release -QtRoot "$env:LOCALAPPDATA\Qt\6.10.3\mingw_64" `
  -MingwRoot "$env:LOCALAPPDATA\Qt\Tools\mingw1310_64" `
  -SigningCertificateThumbprint ABCDEF1234567890
```

SafeNet USB-token certificates are supported. Install and unlock the SafeNet
client first, then either let the script select the only valid code-signing
certificate in `Cert:\CurrentUser\My`, or pass its thumbprint explicitly:

```powershell
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
  Select-Object Subject,Thumbprint,HasPrivateKey,NotAfter
.\build-windows.ps1 release -SigningCertificateThumbprint YOUR_THUMBPRINT
```

Sectigo is used for RFC 3161 timestamps by default. Override it when needed:

```powershell
.\build-windows.ps1 release -TimestampServer http://timestamp.digicert.com
```

The private key stays on the SafeNet token; `signtool` accesses it through the
SafeNet CSP/KSP provider. Keep the token inserted and unlocked so its PIN prompt
can be displayed during signing.

For local testing or distribution through a channel that applies signing later,
use `-Unsigned`. This still builds the Inno Setup installer and deploys all Qt
runtime files, but skips the certificate, `signtool`, and WinUSB catalog signing
checks:

```powershell
.\build-windows.ps1 release -Unsigned
```

The Windows packaging implementation is in
[src/windows/PlatformPackaging.cmake](src/windows/PlatformPackaging.cmake).
The callback relay and resource-generation targets are internal dependencies,
not separate user build channels.

## 3. Linux

### Development and unsigned build

Use the Linux entry point and a separate build directory from any release or
macOS build:

```sh
./build-linux.sh install
./build-linux.sh dev --qt-root=/path/to/qt6 --run
./build-linux.sh build --qt-root=/path/to/qt6
```

For a CLI build, add `--cli`; the entry point passes `-DBUILD_CLI_ONLY=ON` and
builds `zimaos-usb-creator-cli`.

### Release packages

The only supported Linux release orchestrator is
[debian/release.sh](debian/release.sh):

```sh
./build-linux.sh release --target=appimages --arch=amd64 --unsigned
./build-linux.sh release --target=arch --arch=amd64 --signing-key=ABCD1234
./build-linux.sh release --target=repo --signing-key=ABCD1234 --dput-host=pi-internal
```

The release action builds in rootless `mmdebstrap` chroots, caches Qt under
`.debian/`, writes packages to `out/debian/`, signs Debian `.changes`/`.dsc`
with `debsign`, and optionally uploads them with `dput`. `--unsigned` is an
explicit local/testing override. See [doc/linux-build.md](doc/linux-build.md)
for chroots, remote builders, cache controls, and architecture details.

The embedded/netboot package is a Linux auxiliary channel, not a fourth desktop
platform:

```sh
./build-linux.sh release --target=embedded --arch=arm64 --unsigned
```

It uses the dedicated `linuxfb` Qt build and produces an embedded `.deb`.

## Auxiliary

### Qt toolchain

These scripts build Qt; they do not build the application:

| Script | Purpose |
| --- | --- |
| `qt/build-qt-macos.sh` | macOS desktop Qt |
| `qt/build-qt.sh` | Linux desktop Qt |
| `qt/build-qt-cli.sh` | Linux CLI-only Qt |
| `qt/build-qt-embedded.sh` | Linux `linuxfb` embedded Qt |
| `qt/build-qt-armhf.sh` | armhf cross-compiled Qt |

All share [qt/qt-build-common.sh](qt/qt-build-common.sh). Keep the Qt version in
that file or pass `--version`; do not add another hardcoded version to a
platform wrapper.

### Linux AppImage stages

`create-appimage.sh` and `create-appimage-cli.sh` are packaging stages called by
the Debian pipeline. They build an AppDir, deploy Qt and libraries, and then
pack an AppImage. `create-embedded.sh` is the separate linuxfb stage that
assembles the embedded `.deb`. None are macOS or Windows build scripts.

### Debian release stages

`debian/release.sh` is the public orchestrator. Its implementation stages are
`ensure-qt.sh`, `build-appimages.sh`, `build-binary-chroot.sh`,
`build-embedded.sh`, `sync-appimages.sh`, and `stage-appimages.sh`. Chroot,
keyring, apt, and vendor-dependency scripts are infrastructure for those
stages.

### Signing and tests

- macOS signing/notarization: `build-macos.sh release`,
  `setup-notarization.sh`, and the CMake `dmg` target.
- Windows signing/installer: CMake options and targets in
  `src/windows/PlatformPackaging.cmake`.
- CMake tests: configure with `-DBUILD_TESTING=ON`, then build the generated
  test targets. Embedded UI screenshots are under
  `src/test/embedded_scaling/`.

## Known Problems

Legacy source identifiers and URI schemes still contain `rpi-imager` for
backward compatibility. They are not output artifact names. New build outputs
use the `zimaos-usb-creator` prefix consistently.
