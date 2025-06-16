#!/usr/bin/env bash
###
# File: gen-requirements.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

# Set SCRIPT_DIR
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"

poetry export -f requirements.txt -o "${SCRIPT_DIR}"/requirements.txt
