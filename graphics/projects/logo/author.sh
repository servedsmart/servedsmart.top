#!/usr/bin/env bash
###
# File: author.sh
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
INPUT="${SCRIPT_DIR}"/logo.svg
OUTPUT_DIR="${SCRIPT_DIR}"/author
SIZE=512
OUTPUT="${OUTPUT_DIR}"/author-"${SIZE}"x"${SIZE}".png

# Fill FILES variable to match filenames
mkdir -p "${OUTPUT_DIR}"

# Add 30% padding to image and compress
magick -background none -bordercolor none "${INPUT}" -border 15% -resize "${SIZE}" "${OUTPUT}"
oxipng -a -s -o 4 "${OUTPUT}"

# Transfer files to project dir
cp "${OUTPUT}" "${SCRIPT_DIR}"/../../../assets/img/
