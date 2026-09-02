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

### Anonymous metrics (telemetry)

#### Why and what

ZimaOS USB Creator inherits the telemetry system from the original Raspberry Pi Imager.
The telemetry data is sent to Raspberry Pi's servers, not ZimaOS servers.

In order to understand usage of the application (e.g. uptake of ZimaOS USB Creator versions and which images and operating systems are most popular), the application collects anonymous metrics (telemetry) by default. These metrics contain the following information:

- The URL of the OS you have selected
- The category of the OS you have selected
- The observed name of the OS you have selected
- The version of ZimaOS USB Creator
- A flag to say if the tool is being used on the Desktop or as part of the Network Installer
- The host operating system version (e.g. Windows 11)
- The host operating system architecture (e.g. arm64, x86_64)
- The host operating system locale name (e.g. en-GB)

#### Where is it stored

This web service is hosted by [Heroku](https://www.heroku.com) and only stores an incrementing counter using a [Redis Sorted Set](https://redis.io/topics/data-types#sorted-sets) for each URL, operating system name and category per day in the `eu-west-1` region and does not associate any personal data with those counts. This allows us to query the number of downloads over time and nothing else.

The last 1,500 requests to the service are logged for one week before expiring as this is the [minimum log retention period for Heroku](https://devcenter.heroku.com/articles/logging#log-history-limits).

#### Viewing the data

As the data is stored in aggregate form, only aggregate data is available to any viewer. See what we see at: [rpi-imager-stats](https://rpi-imager-stats.raspberrypi.com)

#### Opting out

The most convenient way to opt-out of anonymous metric collection is via the ZimaOS USB Creator UI:

- Select "App Options"
- Untoggle "Enable anonymous statistics (telemetry) collection"
- Press "Save"

## Acknowledgments

This project is based on the excellent work of the Raspberry Pi Foundation and their Raspberry Pi Imager tool. We are grateful for their contribution to the open-source community.
