#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${project_dir}/Resources/DevicePhotos"
chroma_helper="/home/wee/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

mkdir -p "${output_dir}"

process_atlas() {
    local atlas="$1"
    shift
    local names=("$@")
    local atlas_dir="${work_dir}/$(basename "${atlas}" .png)"
    mkdir -p "${atlas_dir}"

    magick "${atlas}" -crop 4x2@ +repage "${atlas_dir}/tile-%d.png"
    for index in "${!names[@]}"; do
        local keyed="${atlas_dir}/tile-${index}.png"
        local transparent="${atlas_dir}/transparent-${index}.png"
        local destination="${output_dir}/${names[$index]}"

        python3 "${chroma_helper}" \
            --input "${keyed}" \
            --out "${transparent}" \
            --auto-key border \
            --soft-matte \
            --transparent-threshold 12 \
            --opaque-threshold 220 \
            --despill

        magick "${transparent}" \
            -trim +repage \
            -resize '232x232>' \
            -gravity center \
            -background none \
            -extent 256x256 \
            -strip \
            "${destination}"
    done
}

process_atlas "${project_dir}/artwork/device-atlas-01.png" \
    iphone-6s.png iphone-6s-plus.png iphone-se-1.png iphone-7.png \
    iphone-7-plus.png iphone-8.png iphone-8-plus.png iphone-x.png

process_atlas "${project_dir}/artwork/device-atlas-02.png" \
    iphone-xs.png iphone-xs-max.png iphone-xr.png iphone-11.png \
    iphone-11-pro.png iphone-11-pro-max.png iphone-se-2.png iphone-12-mini.png

process_atlas "${project_dir}/artwork/device-atlas-03.png" \
    iphone-12.png iphone-12-pro.png iphone-12-pro-max.png iphone-13-mini.png \
    iphone-13.png iphone-13-pro.png iphone-13-pro-max.png iphone-se-3.png

process_atlas "${project_dir}/artwork/device-atlas-04.png" \
    iphone-14.png iphone-14-plus.png iphone-14-pro.png iphone-14-pro-max.png \
    iphone-15.png iphone-15-plus.png iphone-15-pro.png iphone-15-pro-max.png

cp "${output_dir}/iphone-x.png" "${output_dir}/iphone-generic.png"

