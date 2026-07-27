#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

python3 -m json.tool ../repo/sileodepiction.json >/dev/null
python3 -m json.tool resources/device_catalog.json >/dev/null
xmllint --noout packaging/Entitlements.plist resources/Info.plist packaging/ControlCenterModule/Info.plist

package_version="$(sed -n 's/^Version: //p' control)"
bundle_version="$(xmllint --xpath 'string(//key[.="CFBundleShortVersionString"]/following-sibling::string[1])' resources/Info.plist)"
module_version="$(xmllint --xpath 'string(//key[.="CFBundleShortVersionString"]/following-sibling::string[1])' packaging/ControlCenterModule/Info.plist)"
source_version="$(awk -F'"' '/^#define IFETCH_VERSION / { print $2 }' core/IFVersion.h)"
if [[ "${package_version}" != "${bundle_version}" || "${package_version}" != "${module_version}" || "${package_version}" != "${source_version}" ]]; then
    echo "Version mismatch: control=${package_version}, app=${bundle_version}, module=${module_version}, source=${source_version}" >&2
    exit 1
fi

missing=0
while IFS= read -r image; do
    if [[ ! -f "resources/DevicePhotos/${image}" ]]; then
        echo "Missing device image: ${image}" >&2
        missing=1
    fi
done < <(sed -n 's/.*@"image": @"\([^"]*\.png\)".*/\1/p' core/IFetchCore.m | sort -u)

while IFS= read -r image; do
    if [[ ! -f "resources/DevicePhotos/${image}" ]]; then
        echo "Missing device image from device_catalog.json: ${image}" >&2
        missing=1
    fi
done < <(python3 -c 'import json; print("\n".join(sorted({v["image"] for v in json.load(open("resources/device_catalog.json")).values()})))')
if [[ "${missing}" -ne 0 ]]; then
    exit 1
fi

image_count="$(find resources/DevicePhotos -maxdepth 1 -name '*.png' | wc -l)"
if [[ "${image_count}" -lt 33 ]]; then
    echo "Expected at least 33 device images, found ${image_count}" >&2
    exit 1
fi

package="../packages/com.wee1ka.ifetch_${package_version}_iphoneos-arm64.deb"
if [[ -f "${package}" ]]; then
    listing="$(dpkg-deb -c "${package}")"
    if ! grep -q 'IFetch.app/IFetch' <<<"${listing}"; then
        echo "Application binary is missing from package" >&2
        exit 1
    fi
    if ! grep -q 'usr/bin/ifetch' <<<"${listing}"; then
        echo "CLI binary is missing from package" >&2
        exit 1
    fi
    if ! grep -q 'Library/ControlCenter/Bundles/IFetchModule.bundle/IFetchModule' <<<"${listing}"; then
        echo "Control Center module is missing from package" >&2
        exit 1
    fi
fi

echo "iFetch project validation passed"
