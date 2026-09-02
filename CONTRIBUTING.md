## Contributing

The authoritative platform and auxiliary build map is
[doc/build-channels.md](./doc/build-channels.md). The sections below retain deeper Linux release and
embedded-package details.

### Linux

Linux artifacts are built by one pipeline, driven from `build-linux.sh`. It
builds every architecture — amd64, arm64 and armhf — inside its own rootless
`mmdebstrap` chroot, from a machine of any of those architectures, and needs no
`sudo`. [doc/linux-build.md](./doc/linux-build.md) is the full reference; this is
the short version.

#### Get dependencies

Only what is needed to drive the pipeline; the actual build dependencies are
installed inside the chroot:

```sh
./build-linux.sh install
```

To build an architecture other than your own, also install `qemu-user-static`
and `binfmt-support`.

#### Get the source

```sh
git clone https://github.com/raspberrypi/rpi-imager
```

Clone with full history: version strings come from `git describe --tags`, and
the vendored third-party dependencies are git submodules (initialised for you by
`debian/fetch-vendor-deps.sh`). A `--depth 1` clone will not build.

#### Build the release artifacts

```sh
./build-linux.sh release --target=appimages --arch=amd64 --unsigned
./build-linux.sh release --target=arch --arch=amd64 --unsigned

# All three architectures, plus the source package. RELEASE_ARCHES defaults to
# your own architecture alone, so pass it explicitly (or set it in release.conf).
./build-linux.sh release --target=repo --unsigned
```

`repo` is the only command that builds more than one architecture; the others
take exactly one.

The first run bootstraps a chroot and builds Qt, so it takes a while; both are
cached under `.debian/` afterwards. Finished AppImages land in
`.debian/appimages/<arch>/` and packages in `out/debian/`.

#### Build quickly while developing

To iterate on the app itself, skip the packaging and build against a Qt tree
directly:

```sh
./build-linux.sh dev --qt-root=/path/to/qt6 --run
```

`<version>` is whatever `QT_VERSION_DEFAULT` in
[qt/qt-build-common.sh](./qt/qt-build-common.sh) says — the single place the Qt
version is selected.

### Windows

#### Get dependencies

- Get the Qt online installer from: https://www.qt.io/download-open-source
  - During installation, choose the Qt version named by `QT_VERSION_DEFAULT` in [qt/qt-build-common.sh](./qt/qt-build-common.sh), with the Mingw64 64-bit toolchain. Any newer Qt 6 that satisfies the `find_package(Qt6 ...)` minimum in `src/CMakeLists.txt` will also configure.
- For building the installer, install Inno Setup scriptable install system: https://jrsoftware.org/isdl.php
- Install Visual Studio Code (or a derivative) and the Qt Extension Pack.
- It is assumed you already have a valid code signing certificate, and the Windows 10 Kit (SDK) installed.

#### Building

Use the PowerShell entry point described in
[doc/build-channels.md](./doc/build-channels.md):

```powershell
.\build-windows.ps1 install -WithQt
.\build-windows.ps1 dev
.\build-windows.ps1 release -SigningCertificateThumbprint <thumbprint>
```

### macOS

#### Get dependencies

- Build a minimal Qt from source using our build script:
  ```bash
  ./qt/build-qt-macos.sh
  ```
  - This builds only what's needed for rpi-imager, resulting in faster builds and smaller size
  - See `qt/README-qt-build-macos.md` for detailed instructions
- Install Visual Studio Code (or a derivative), and the Qt Extension Pack.
- It is assumed you have an Apple developer subscription, and already have a "Developer ID" code signing certificate for distribution outside the Mac Store.

#### Building

Use the macOS entry point described in
[doc/build-channels.md](./doc/build-channels.md):

```sh
./build-macos.sh install --with-qt
./build-macos.sh dev
./build-macos.sh release --signing-identity="Developer ID Application: ..."
```

### Linux embedded (netboot) build

The Raspberry Pi Network installer (embedded imager) runs inside an operating system created by [pi-gen-micro](https://github.com/raspberrypi/pi-gen-micro/tree/main/configurations/rpi-imager-embedded).

It uses a **dedicated** Qt, distinct from the desktop and CLI release Qt: built
`-no-opengl -no-dbus -qpa linuxfb` by `qt/build-qt-embedded.sh` into its own
cache variant (`gcc_arm64_embedded`). The netboot target image carries no
Mesa/GL, no X11 and no session bus — far too large for a network-loaded image —
so the embedded Qt must not link `libEGL`/`libGL`/`libX11` at all. The build
below produces it automatically on a cache miss.

The canonical build goes through the release pipeline, which builds inside the
arm64 mmdebstrap chroot:

```sh
./build-linux.sh release --target=embedded --arch=arm64 --unsigned
```

This produces `out/debian/zimaos-usb-creator-embedded_<version>_arm64.deb`. It stages the
vendored `/opt` tree with `create-embedded.sh`, then assembles the `.deb` with
debhelper so that `debian/control` is the single source of the package's
dependencies and metadata (`dh_shlibdeps` is deliberately not used — the package
vendors its libraries, so the external `Depends` are maintained explicitly in
the `zimaos-usb-creator-embedded` stanza of `debian/control`).

The embedded Qt and packaging scripts are internal pipeline stages. Do not run
them directly; the Linux entry point creates the dedicated Qt cache on demand.

Finally, import the package into pi-gen-micro:

```sh
rm ${pi-gen-micro-root}/packages/zimaos-usb-creator-embedded*.deb
cp out/debian/zimaos-usb-creator-embedded*.deb ${pi-gen-micro-root}/packages/
pushd ${pi-gen-micro-root}/packages/ && dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz && popd
```
