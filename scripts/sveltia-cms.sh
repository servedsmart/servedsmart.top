#!/usr/bin/env bash
###
# File: sveltia-cms.sh
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
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/sveltia-cms.conf

# Get ./sveltia-cms.js
curl --proto '=https' --tlsv1.2 -sSfL https://unpkg.com/@sveltia/cms@"${SVELTIA_VERSION}"/dist/sveltia-cms.js -o "${SCRIPT_DIR}"/../assets/js/edit-cms-sveltia.js

# Execute sveltia-cms-conf.sh
"${SCRIPT_DIR}"/sveltia-cms-config.sh
