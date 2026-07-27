<div align="center">
  <img src="https://weekanya.github.io/iFetch/ifetch-banner.png" alt="iFetch" width="100%">
</div>

<div align="center">
  <strong>English</strong> · <a href="README_RU.md">Русский</a>
</div>

# iFetch

iFetch is a diagnostics toolkit for iPhones running a rootless jailbreak on
iOS 14–17. It combines a native system dashboard, process explorer, crash-log
viewer, tweak inspection, a Control Center module, and a command-line client.

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
- battery health, real and design capacity, temperature, voltage, current,
  charging power, and cycle count;
- system uptime and thermal state;
- live CPU, memory, network, battery-level, and temperature charts;
- process explorer with PID, executable path, threads, uptime, and injected
  tweak information;
- real-time download and upload speed;
- IPv4/IPv6, local and public IP addresses, DNS, Wi-Fi, cellular technology,
  active interface, VPN, per-interface traffic, and latency;
- jailbreak environment and installed hook injector;
- Jailbreak Health checks with clear warning states;
- searchable installed-tweak list with package versions and injection filters;
- crash-log browsing, previewing, copying, and sharing.

iFetch detects ElleKit, Cydia Substrate, libhooker, and Substitute. Models from
the iPhone 6s through the iPhone 15 Pro Max are supported, with a separate
device image for each model.

## System actions

The app can perform:

- Respring;
- icon cache refresh;
- Safe Mode;
- Userspace Reboot;
- full or privacy-redacted system report export.

Actions that can interrupt the current session require confirmation. iFetch
also reports missing commands and execution errors instead of silently failing.

## Command-line tool

Open NewTerm or connect to the device over SSH, then run:

```sh
ifetch
```

The command prints an ASCII logo followed by device, jailbreak, network,
memory, storage, battery, and process information. It also supports scripting
and live monitoring:

```sh
ifetch --watch
ifetch --json
ifetch --processes 10
ifetch --network
ifetch --battery
ifetch --lang ru
ifetch --no-color
```

## Control Center

Version 3.0 includes an optional iFetch module showing CPU, RAM, network speed,
and battery temperature. CCSupport is recommended so the module can be added
to the Control Center layout.

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
make -C src clean package FINALPACKAGE=1
```

The finished package is written to:

```text
packages/com.wee1ka.ifetch_3.0.2_iphoneos-arm64.deb
```

Run the project checks with:

```sh
src/scripts/validate_project.sh
```

## System access and privacy

iFetch is designed for a jailbreak environment and is signed with extended
entitlements. They are required to read process information, battery data, and
other system statistics.

Almost all information is collected locally. A single HTTPS request is sent to
`api.ipify.org` to determine the public IP address. If the service is
unavailable, iFetch displays `Unavailable`.

## Source layout

- `src/app` — UIKit application and screens;
- `src/core` — shared system monitoring and diagnostics;
- `src/cli` — command-line version;
- `src/control-center` — CCSupport module;
- `src/resources` — application resources, localization, device catalog, and images;
- `src/packaging` — entitlements and Control Center bundle metadata;
- `src/artwork` — source device atlases;
- `src/scripts` — project validation and artwork processing tools;
- `docs/releases` — release notes;
- `repo` — source files for the Sileo repository;

The `src` directory also contains the Theos `Makefile` and package `control`
file, keeping everything related to the application in one place.

## License

MIT. See [LICENSE](LICENSE).
