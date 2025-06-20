#!/usr/bin/env bash
###
# File: update-deps.sh
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

# INFO: This script doesn't merge anything, changes will have to be done according to git history. It just curls the latest changes from upstream.

curl -Lso "${SCRIPT_DIR}"/../assets/js/appearance.js https://raw.githubusercontent.com/nunocoracao/blowfish/refs/heads/main/assets/js/appearance.js
curl -Lso "${SCRIPT_DIR}"/../layouts/_default/baseof.html https://raw.githubusercontent.com/nunocoracao/blowfish/refs/heads/main/layouts/_default/baseof.html
