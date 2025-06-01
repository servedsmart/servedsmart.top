#!/usr/bin/env bash
###
# File: install-dependency-pup.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

REPO_DIR="$(mktemp -d /tmp/pup-XXXXXX)"
git clone https://github.com/servedsmart/pup "${REPO_DIR}"
cd "${REPO_DIR}"
go build -o /tmp/pup
sudo mv /tmp/pup /usr/bin/pup
