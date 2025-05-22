#!/usr/bin/env bash
###
# File: favicon.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"

# Define variables
INPUT="${SCRIPT_DIR}"/../graphics/projects/logo/logo.svg
OUTPUT_DIR="${SCRIPT_DIR}"/../graphics/projects/logo/favicon
## These will only be exported as png
SIZES=(
    16
    32
    180
    192
    512
)
## These will also be included in .ico
SIZES_ICO="16,32,48"

# Fill FILES variable to match filenames
mkdir -p "${OUTPUT_DIR}"
for size in "${SIZES[@]}"; do
    if [[ "${size}" -eq 512 ]] || [[ "${size}" -eq 192 ]]; then
        FILES+=("${OUTPUT_DIR}"/android-chrome-"${size}"x"${size}".png)
        continue
    fi
    if [[ "${size}" -eq 180 ]]; then
        FILES+=("${OUTPUT_DIR}"/apple-touch-icon.png)
        continue
    fi
    FILES+=("${OUTPUT_DIR}"/favicon-"${size}"x"${size}".png)
done

# Convert images with inkscape and compress
SIZES_LENGTH="${#SIZES[@]}"
for ((i = 0; i < SIZES_LENGTH; i++)); do
    SIZE="${SIZES[${i}]}"
    OUTPUT="${FILES[${i}]}"
    inkscape "${INPUT}" -h "${SIZE}" -w "${SIZE}" -o "${OUTPUT}"
    oxipng -a -s -o 4 "${OUTPUT}"
done

# Create favicon.ico
magick -background none "${INPUT}" -define icon:auto-resize="${SIZES_ICO}" "${OUTPUT_DIR}"/favicon.ico

# Transfer files to project dir
cp "${OUTPUT_DIR}"/*.png "${SCRIPT_DIR}"/../static/

# Execute author.sh
"${SCRIPT_DIR}"/author.sh
