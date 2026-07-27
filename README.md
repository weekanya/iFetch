<div align="center">
  <img src="https://weebio.ru/sfc/ifetch-banner.png" alt="iFetch" width="100%">
</div>

<div align="center">
  <strong>English</strong> · <a href="README_RU.md">Русский</a>
</div>

# iFetch

iFetch is a system monitor for iPhones running a rootless jailbreak on
iOS 14–17. It shows device information, helps identify resource-heavy
processes, and keeps the most useful jailbreak details in one place.

The interface is built with UIKit and follows the look of the native iOS
Settings app. The package also installs the `ifetch` command for NewTerm and
SSH.

English is used by default. Russian can be selected under
`Tools → Settings → Language`. The selected language is saved for both the app
and the command-line tool.

<div align="center">
  <img src="https://weebio.ru/sfc/s2.png" alt="iFetch overview" width="48%">
  <img src="https://weebio.ru/sfc/s1.png" alt="iFetch system information" width="48%">
</div>

## System information

- iPhone model, hardware identifier, chip, architecture, and Darwin version;
- memory and storage usage;
- battery level, charging state, and cycle count;
- system uptime and thermal state;
- Top-3 processes by memory and CPU usage;
- real-time download and upload speed;
- local and public IP addresses, DNS servers, active interface, and VPN;
- jailbreak environment and installed hook injector;
- installed packages, active tweaks, and crash logs from the last 24 hours.

iFetch detects ElleKit, Cydia Substrate, libhooker, and Substitute. Models from
the iPhone 6s through the iPhone 15 Pro Max are supported, with a separate
device image for each model.

## System actions

The app can perform:

- Respring;
- icon cache refresh;
- Safe Mode;
- Userspace Reboot;
- system report export.

Actions that can interrupt the current session require confirmation. iFetch
also reports missing commands and execution errors instead of silently failing.

## Command-line tool

Open NewTerm or connect to the device over SSH, then run:

```sh
ifetch
```

The command prints an ASCII logo followed by device, jailbreak, network,
memory, storage, and process information.

## Compatibility

- iOS 14–17;
- rootless jailbreak;
- `iphoneos-arm64` package architecture;
- minimum deployment target: iOS 14.0.

The executable uses a compatible `arm64` slice and also runs on devices with
`arm64e` hardware.

## Building

Theos and the iOS 16.5 SDK or newer are required:

```sh
make clean package FINALPACKAGE=1
```

The finished package is written to:

```text
packages/com.wee1ka.ifetch_2.1.0_iphoneos-arm64.deb
```

Run the project checks with:

```sh
scripts/validate_project.sh
```

## System access and privacy

iFetch is designed for a jailbreak environment and is signed with extended
entitlements. They are required to read process information, battery data, and
other system statistics.

Almost all information is collected locally. A single HTTPS request is sent to
`api.ipify.org` to determine the public IP address. If the service is
unavailable, iFetch displays `Unavailable`.

## Source layout

- `IFetchCore.m` — shared system monitoring logic;
- `RootViewController.m` — UIKit interface;
- `cli/main.m` — command-line version;
- `Resources/DevicePhotos` — device images;
- `artwork` — source device atlases;
- `scripts/process_device_atlases.sh` — atlas processing script.

## License

MIT. See [LICENSE](LICENSE).
