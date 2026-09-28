# ZimaOS USB Creator

> **Note**: This project is a fork of [Raspberry Pi Imager](https://github.com/raspberrypi/rpi-imager) by Raspberry Pi Ltd, licensed under Apache-2.0.

ZimaOS USB Imaging Utility - A tool for creating bootable USB drives for ZimaOS.

## About This Fork

This is a modified version of the Raspberry Pi Imager, adapted specifically for ZimaOS. Key changes include:
- Rebranded user interface to "ZimaOS USB Creator"
- Modified to work with ZimaOS image repositories
- Updated translations and localization
- Customized for ZimaOS ecosystem

**Original project**: https://github.com/raspberrypi/rpi-imager

## License

This project maintains the Apache-2.0 license of the original Raspberry Pi Imager.
- Original work: Copyright (C) 2020 Raspberry Pi Ltd
- Modifications: Copyright (C) 2026 IceWhale Technology Ltd.

See [license.txt](license.txt) for full license details.

## Installation

### From Binary Releases

Download the latest release for your platform from the Releases page.

### Building from Source

For the authoritative macOS, Windows, and Linux build channels, including all
auxiliary Qt, AppImage, Debian, embedded, and signing stages, see
[doc/build-channels.md](./doc/build-channels.md). It is the only build interface
reference; use `build-macos.sh`, `build-windows.ps1`, or `build-linux.sh` rather
than calling packaging-stage scripts directly. Contributing and embedded-package
details are in [CONTRIBUTING.md](./CONTRIBUTING.md).

## Other notes

### Custom repository

If the application is started with "--repo [your own URL]" it will use a custom image repository.
So can simply create another 'start menu shortcut' to the application with that parameter to use the application with your own images.

### Privacy and network access

ZimaOS USB Creator does not send anonymous usage telemetry to Raspberry Pi.
Raspberry Pi Connect integration has been removed: the application does not
request Connect authorization keys, accept Connect sign-in tokens, or provision
Connect credentials and services in OS images.

The application still uses the network to retrieve image repositories, download
images and icons, and check for application updates. The default image repository
is hosted at `https://release.zimaos.com/zimaos-manifest.json`; custom repositories
and their images may use other servers.

Performance diagnostics can be exported to a local JSON file; they are not
automatically uploaded.

## Acknowledgments

This project is based on the excellent work of the Raspberry Pi Foundation and their Raspberry Pi Imager tool. We are grateful for their contribution to the open-source community.
