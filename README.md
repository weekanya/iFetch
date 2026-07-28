<div align="center">
  <img src="repo/ifetch-banner.png" alt="iFetch" width="100%">
</div>

<div align="center">
  <strong>English</strong> · <a href="README_RU.md">Русский</a>
</div>

# iFetch

[![Build Rootless Artifact](https://github.com/weekanya/iFetch/actions/workflows/build-artifact.yml/badge.svg)](https://github.com/weekanya/iFetch/actions/workflows/build-artifact.yml)

iFetch is a system diagnostics app for iPhones running a rootless jailbreak on
iOS 14–17. It includes a native UIKit app, Home Screen widgets, a Control
Center module, and the `ifetch` command for NewTerm and SSH.

<div align="center">
  <img src="assets/en1.png" alt="iFetch overview" width="48%">
  <img src="assets/en2.png" alt="iFetch diagnostics" width="48%">
</div>

## Features

- live CPU, memory, storage, battery, temperature, and network monitoring;
- process explorer with tweak details and confirmed process termination;
- Wi-Fi, DNS, VPN, public IP, traffic speed, and latency information;
- jailbreak environment, hook injector, installed tweaks, and crash reports;
- small, medium, and large WidgetKit widgets;
- 2×2 CCSupport module for Control Center;
- English and Russian interface.

## Install

Add the repository to Sileo and install **iFetch**:

```text
https://weekanya.github.io/iFetch/
```

Only rootless jailbreaks are supported. The package architecture is
`iphoneos-arm64`, with iOS 14.0 as the minimum deployment target.

## Terminal

Run `ifetch` in NewTerm or over SSH. Useful options include:

```sh
ifetch --watch
ifetch --json
ifetch --processes 10
ifetch --network
ifetch --battery
ifetch --lang ru
```

## Build

To build locally:

```sh
make -C src clean package FINALPACKAGE=1
```

You can also run
[Build Rootless Artifact](https://github.com/weekanya/iFetch/actions/workflows/build-artifact.yml)
without installing Theos locally. It produces a rootless `.deb`, checksum, and
build information. Tools are cached and artifacts are kept for 30 days. The
package is not published as a release.

## Privacy

System information is collected locally. iFetch contacts `api.ipify.org` only
to determine the public IP address.

## License

MIT. See [LICENSE](LICENSE).
