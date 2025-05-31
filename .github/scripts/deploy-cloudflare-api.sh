#!/usr/bin/env bash
###
# File: deploy-cloudflare-api.sh
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
. "${SCRIPT_DIR}"/deploy-cloudflare-api.conf

# Make copy of current repo
ROOT_DIR="$(mktemp /tmp/site-XXXXXX)"
cp -R "${SCRIPT_DIR}"/../.. "${ROOT_DIR}"
cd "${ROOT_DIR}"

# Response Header Transform Rules
## Get SCRIPT_HASHES and STYLE_HASHES for every branch
### Set DELIMITER to fixed 64 byte string.
DELIMITER="p4qqrKQ3QZ8nNs6QqTNWwEYFaAoqYWceGkwshO82TPdYFWa2tA68oBRn29IbkYvn"
### Fetch remote branches and loop through them
git remote set-branches origin '*'
git fetch --depth=1
for branch in $(git for-each-ref --format='%(refname:short)' refs/heads); do
    #### Build current branch
    git restore .
    git switch --recurse-submodules "${branch}"
    hugo --enableGitInfo --minify -e "production" -d ./public
    #### Get content of <script> tags as array
    SCRIPT_TAG_CONTENT="$(find "${ROOT_DIR}"/public -type f -name "*.html" -exec sh -c 'hxnormalize -xe "${1}" | hxselect -ics '"${DELIMITER}"' script' _ {} \;)"
    SCRIPT_TAG_CONTENT="${SCRIPT_TAG_CONTENT//$'\n'/\\n}"
    readarray -t SCRIPTS < <(printf '%s\n' "${SCRIPT_TAG_CONTENT}" | awk -v RS="${DELIMITER}" '1')
    #### Remove empty elements and duplicates
    SCRIPTS_LENGTH="${#SCRIPTS[@]}"
    for ((i = 0; i < SCRIPTS_LENGTH; i++)); do
        if [[ -z "${SCRIPTS[${i}]}" ]]; then
            unset 'SCRIPTS[${i}]'
        fi
    done
    declare -A SCRIPTS_
    for script in "${SCRIPTS[@]}"; do
        SCRIPTS_["${script}"]=1
    done
    readarray -t SCRIPTS < <(printf '%s\n' "${!SCRIPTS_[@]}")
    #### Get SCRIPT_HASHES from SCRIPTS
    for script_ in "${SCRIPTS[@]}"; do
        script="$(printf "%b\n" "${script_}")"
        SCRIPT_HASHES+=("'sha256-$(printf '%s\n' "$(printf '%s' "${script}" | openssl sha256 -binary | openssl base64)'")")
    done
    #### Remove duplicates
    declare -A SCRIPT_HASHES_
    for script_hash in "${SCRIPT_HASHES[@]}"; do
        SCRIPT_HASHES_["${script_hash}"]=1
    done
    readarray -t SCRIPT_HASHES < <(printf '%s\n' "${!SCRIPT_HASHES_[@]}")
    #### Get content of <style> tags as array
    STYLE_TAG_CONTENT="$(find "${ROOT_DIR}"/public -type f -name "*.html" -exec sh -c 'hxnormalize -xe "${1}" | hxselect -ics '"${DELIMITER}"' style' _ {} \;)"
    STYLE_TAG_CONTENT="${STYLE_TAG_CONTENT//$'\n'/\\n}"
    readarray -t STYLES < <(printf '%s\n' "${STYLE_TAG_CONTENT}" | awk -v RS="${DELIMITER}" '1')
    #### Remove empty elements and duplicates
    STYLES_LENGTH="${#STYLES[@]}"
    for ((i = 0; i < STYLES_LENGTH; i++)); do
        if [[ -z "${STYLES[${i}]}" ]]; then
            unset 'STYLES[${i}]'
        fi
    done
    declare -A STYLES_
    for style in "${STYLES[@]}"; do
        STYLES_["${style}"]=1
    done
    readarray -t STYLES < <(printf '%s\n' "${!STYLES_[@]}")
    #### Get STYLE_HASHES from STYLES
    for style_ in "${STYLES[@]}"; do
        style="$(printf "%b\n" "${style_}")"
        STYLE_HASHES+=("'sha256-$(printf '%s\n' "$(printf '%s' "${style}" | openssl sha256 -binary | openssl base64)'")")
    done
    #### Remove duplicates
    declare -A STYLE_HASHES_
    for style_hash in "${STYLE_HASHES[@]}"; do
        STYLE_HASHES_["${style_hash}"]=1
    done
    readarray -t STYLE_HASHES < <(printf '%s\n' "${!STYLE_HASHES_[@]}")
done
## Restore and switch back to main
git restore .
git switch main
hugo --enableGitInfo --minify -e "production" -d ./public

## https://content-security-policy.com/
RULES_CSP_DEFAULT=(
    "default-src 'none'"
    "script-src 'self' ${SCRIPT_HASHES[@]}"
    "style-src 'self' ${STYLE_HASHES[@]}"
    "img-src 'self' blob: data:"
    "connect-src 'self'"
    "font-src 'self'"
    "object-src 'self'"
    "media-src blob:"
    "frame-src blob: https://www.youtube-nocookie.com"
    "child-src blob: https://www.youtube-nocookie.com"
    "form-action 'none'"
    "frame-ancestors 'none'"
    "base-uri 'none'"
    "worker-src 'none'"
    "manifest-src 'self'"
    "prefetch-src 'none'"
    "require-trusted-types-for 'script'"
    "trusted-types 'none'"
    "upgrade-insecure-requests"
    "block-all-mixed-content"
)
### https://github.com/sveltia/sveltia-cms?tab=readme-ov-file#setting-up-content-security-policy
RULES_CSP_CMS=(
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com"
    "font-src 'self' https://fonts.gstatic.com"
    "img-src 'self' blob: data: https://*.githubusercontent.com"
    "media-src blob:"
    "frame-src blob: https://www.youtube-nocookie.com"
    "child-src blob: https://www.youtube-nocookie.com"
    "script-src 'self' https://unpkg.com"
    "connect-src 'self' blob: data: https://unpkg.com https://api.github.com https://www.githubstatus.com"
    "upgrade-insecure-requests"
    "block-all-mixed-content"
)
RULES_CSP_DEFAULT_LENGTH="${#RULES_CSP_DEFAULT[@]}"
for ((i = 0; i < RULES_CSP_DEFAULT_LENGTH; i++)); do
    if ((i != RULES_CSP_DEFAULT_LENGTH - 1)); then
        #### Join into string
        CSP_DEFAULT+="${RULES_CSP_DEFAULT[${i}]}; "
        continue
    fi
    #### Join into string
    CSP_DEFAULT+="${RULES_CSP_DEFAULT[${i}]}"
done
RULES_CSP_CMS_LENGTH="${#RULES_CSP_CMS[@]}"
for ((i = 0; i < RULES_CSP_CMS_LENGTH; i++)); do
    if ((i != RULES_CSP_CMS_LENGTH - 1)); then
        #### Join into string
        CSP_CMS+="${RULES_CSP_CMS[${i}]}; "
        continue
    fi
    #### Join into string
    CSP_CMS+="${RULES_CSP_CMS[${i}]}"
done
## https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Permissions-Policy
RULES_PP_DEFAULT=(
    # https://github.com/w3c/webappsec-permissions-policy/blob/main/features.md#standardized-features
    "accelerometer=()"
    "ambient-light-sensor=()"
    "attribution-reporting=()"
    "autoplay=()"
    "battery=()"
    "bluetooth=()"
    "camera=()"
    "ch-ua=()"
    "ch-ua-arch=()"
    "ch-ua-bitness=()"
    "ch-ua-full-version=()"
    "ch-ua-full-version-list=()"
    "ch-ua-high-entropy-values=()"
    "ch-ua-mobile=()"
    "ch-ua-model=()"
    "ch-ua-platform=()"
    "ch-ua-platform-version=()"
    "ch-ua-wow64=()"
    "compute-pressure=()"
    "cross-origin-isolated=()"
    "direct-sockets=()"
    "display-capture=()"
    "encrypted-media=()"
    "execution-while-not-rendered=()"
    "execution-while-out-of-viewport=()"
    'fullscreen=(self \"https://www.youtube-nocookie.com\")'
    "geolocation=()"
    "gyroscope=()"
    "hid=()"
    "identity-credentials-get=()"
    "idle-detection=()"
    "keyboard-map=()"
    "magnetometer=()"
    "mediasession=()"
    "microphone=()"
    "midi=()"
    "navigation-override=()"
    "otp-credentials=()"
    "payment=()"
    "picture-in-picture=()"
    "publickey-credentials-get=()"
    "screen-wake-lock=()"
    "serial=()"
    "sync-xhr=()"
    "storage-access=()"
    "usb=()"
    "web-share=()"
    "window-management=()"
    "xr-spatial-tracking=()"
    # https://github.com/w3c/webappsec-permissions-policy/blob/main/features.md#proposed-features
    "clipboard-read=()"
    "clipboard-write=(self)"
    "deferred-fetch=()"
    "gamepad=()"
    "shared-autofill=()"
    "speaker-selection=()"
    # https://github.com/w3c/webappsec-permissions-policy/blob/main/features.md#experimental-features
    "all-screens-capture=()"
    "browsing-topics=()"
    "captured-surface-control=()"
    "conversion-measurement=()"
    "digital-credentials-get=()"
    "focus-without-user-activation=()"
    "join-ad-interest-group=()"
    "local-fonts=()"
    "run-ad-auction=()"
    "smart-card=()"
    "sync-script=()"
    "trust-token-redemption=()"
    "unload=()"
    "vertical-scroll=()"
    # https://github.com/w3c/webappsec-permissions-policy/blob/main/features.md#retired-features
    "document-domain=()"
    "window-placement=()"
)
RULES_PP_DEFAULT_LENGTH="${#RULES_PP_DEFAULT[@]}"
for ((i = 0; i < RULES_PP_DEFAULT_LENGTH; i++)); do
    if ((i != RULES_PP_DEFAULT_LENGTH - 1)); then
        #### Join into string
        PP_DEFAULT+="${RULES_PP_DEFAULT[${i}]}, "
        continue
    fi
    #### Join into string
    PP_DEFAULT+="${RULES_PP_DEFAULT[${i}]}"
done
## Generate EXPRESSION_CMS with languages used
EXPRESSION_CMS="(starts_with(http.request.uri.path, \\\"/edit-cms\\\"))"
DEFAULT_LOCALE="$(tomlq -cr ".defaultContentLanguage" "${ROOT_DIR}"/config/_default/hugo.toml)"
for file in "${ROOT_DIR}"/config/_default/languages.*.toml; do
    LOCALE="$(basename "${file}" .toml | cut -d. -f2)"
    if [[ "${LOCALE}" != "${DEFAULT_LOCALE}" ]]; then
        ### Append expression
        EXPRESSION_CMS+=" or (starts_with(http.request.uri.path, \\\"/${LOCALE}/edit-cms\\\"))"
    fi
done
## https://developers.cloudflare.com/ruleset-engine/rulesets-api/create/
### https://developers.cloudflare.com/rules/transform/response-header-modification/create-api/
JSON_RESPONSE_HEADER_TRANSFORM_RULESET="$(
    cat <<EOF | jq -c
{
  "name": "Secure HTTP Response Headers",
  "description": "Generated by ${REPO_URL}",
  "kind": "zone",
  "phase": "http_response_headers_transform",
  "rules": [
    {
      "expression": "true",
      "description": "Secure HTTP Response Headers",
      "action": "rewrite",
      "action_parameters": {
        "headers": {
          "Content-Security-Policy": {
            "operation": "set",
            "value": "${CSP_DEFAULT}"
          },
          "Permissions-Policy": {
            "operation": "set",
            "value": "${PP_DEFAULT}"
          },
          "X-XSS-Protection": {
            "operation": "set",
            "value": "0"
          },
          "X-Frame-Options": {
            "operation": "set",
            "value": "DENY"
          },
          "X-Content-Type-Options": {
            "operation": "set",
            "value": "nosniff"
          },
          "Referrer-Policy": {
            "operation": "set",
            "value": "no-referrer"
          },
          "Cross-Origin-Embedder-Policy": {
            "operation": "set",
            "value": "require-corp; report-to=\"default\";"
          },
          "Cross-Origin-Opener-Policy": {
            "operation": "set",
            "value": "same-origin; report-to=\"default\";"
          },
          "Cross-Origin-Resource-Policy": {
            "operation": "set",
            "value": "same-origin"
          },
          "X-Permitted-Cross-Domain-Policies": {
            "operation": "set",
            "value": "none"
          },
          "Public-Key-Pins": {
            "operation": "remove"
          },
          "X-Powered-By": {
            "operation": "remove"
          },
          "X-AspNet-Version": {
            "operation": "remove"
          }
        }
      }
    },
    {
      "expression": "${EXPRESSION_CMS}",
      "description": "Secure HTTP Response Headers for edit-cms",
      "action": "rewrite",
      "action_parameters": {
        "headers": {
          "Content-Security-Policy": {
            "operation": "set",
            "value": "${CSP_CMS}"
          }
        }
      }
    }
  ]
}
EOF
)"
## Check if ruleset exists and either update or create ruleset
API_LIST_RULESETS_ZONE="$(curl -s https://api.cloudflare.com/client/v4/zones/"${CLOUDFLARE_ZONE_ID_0}"/rulesets -X GET -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_1}")"
if ! jq -e ".success" <<<"${API_LIST_RULESETS_ZONE}" >/dev/null 2>&1; then
    echo "ERROR: Cloudflare API Request unsuccessful. GET https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_0/rulesets failed."
    exit 1
fi
RULESET_ID="$(jq -r '.result[] | select(.phase == "http_response_headers_transform") | .id' <<<"${API_LIST_RULESETS_ZONE}")"
if [[ -n "${RULESET_ID}" ]]; then
    RESPONSE="$(curl -s https://api.cloudflare.com/client/v4/zones/"${CLOUDFLARE_ZONE_ID_0}"/rulesets/"${RULESET_ID}" -X PUT -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_1}" --json "${JSON_RESPONSE_HEADER_TRANSFORM_RULESET}")"
    if ! jq -e ".success" <<<"${RESPONSE}" >/dev/null 2>&1; then
        echo "ERROR: Cloudflare API Request unsuccessful. PUT https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_0/rulesets/RULESET_ID failed."
        exit 1
    fi
    echo "Cloudflare API Request successful. PUT https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_0/rulesets/RULESET_ID succeeded."
else
    RESPONSE="$(curl -s https://api.cloudflare.com/client/v4/zones/"${CLOUDFLARE_ZONE_ID_0}"/rulesets -X POST -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_1}" --json "${JSON_RESPONSE_HEADER_TRANSFORM_RULESET}")"
    if ! jq -e ".success" <<<"${RESPONSE}" >/dev/null 2>&1; then
        echo "ERROR: Cloudflare API Request unsuccessful. POST https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_0/rulesets failed."
        exit 1
    fi
    echo "Cloudflare API Request successful. POST https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_0/rulesets succeeded."
fi

# Redirect Rules
## https://developers.cloudflare.com/rules/url-forwarding/single-redirects/create-api/
JSON_REDIRECT_RULESET="$(
    cat <<EOF | jq -c
{
  "name": "Redirect to ${TARGET_DOMAIN}",
  "description": "Generated by ${REPO_URL}",
  "kind": "zone",
  "phase": "http_request_dynamic_redirect",
  "rules": [
    {
      "expression": "(http.host eq \"www.${TARGET_DOMAIN}\")",
      "description": "Redirect to ${TARGET_DOMAIN}",
      "action": "redirect",
      "action_parameters": {
        "from_value": {
          "target_url": {
            "expression": "concat(\"https://${TARGET_DOMAIN}\", http.request.uri.path)"
          },
          "status_code": 301,
          "preserve_query_string": true
        }
      }
    }
  ]
}
EOF
)"
## Either update or create ruleset
RULESET_ID="$(jq -r '.result[] | select(.phase == "http_request_dynamic_redirect") | .id' <<<"${API_LIST_RULESETS_ZONE}")"
if [[ -n "${RULESET_ID}" ]]; then
    RESPONSE="$(curl -s https://api.cloudflare.com/client/v4/zones/"${CLOUDFLARE_ZONE_ID_0}"/rulesets/"${RULESET_ID}" -X PUT -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_1}" --json "${JSON_REDIRECT_RULESET}")"
    if ! jq -e ".success" <<<"${RESPONSE}" >/dev/null 2>&1; then
        echo "ERROR: Cloudflare API Request unsuccessful. PUT https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_0/rulesets/RULESET_ID failed."
        exit 1
    fi
    echo "Cloudflare API Request successful. PUT https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_0/rulesets/RULESET_ID succeeded."
else
    RESPONSE="$(curl -s https://api.cloudflare.com/client/v4/zones/"${CLOUDFLARE_ZONE_ID_0}"/rulesets -X POST -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_1}" --json "${JSON_REDIRECT_RULESET}")"
    if ! jq -e ".success" <<<"${RESPONSE}" >/dev/null 2>&1; then
        echo "ERROR: Cloudflare API Request unsuccessful. POST https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_0/rulesets failed."
        exit 1
    fi
    echo "Cloudflare API Request successful. POST https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_0/rulesets succeeded."
fi
## Process external zone ids
for ((i = 0; i < EXTERNAL_REDIRECT_DOMAINS_LENGTH; i++)); do
    CLOUDFLARE_ZONE_ID_EXTERNAL="$(jq -r --arg secret "${CLOUDFLARE_ZONE_ID_SECRET_NAMES[${i}]}" '.[$secret]' <<<"$JSON_SECRETS")"
    JSON_REDIRECT_RULESET_EXTERNAL="$(jq -c --arg expression "(http.host eq \"${EXTERNAL_REDIRECT_DOMAINS[${i}]}\") or (http.host eq \"www.${EXTERNAL_REDIRECT_DOMAINS[${i}]}\")" '.rules[0].expression = $expression' <<<"${JSON_REDIRECT_RULESET}")"
    ### Check if ruleset exists and either update or create ruleset
    API_LIST_RULESETS_ZONE_EXTERNAL="$(curl -s https://api.cloudflare.com/client/v4/zones/"${CLOUDFLARE_ZONE_ID_EXTERNAL}"/rulesets -X GET -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_1}")"
    if ! jq -e ".success" <<<"${API_LIST_RULESETS_ZONE_EXTERNAL}" >/dev/null 2>&1; then
        echo "ERROR: Cloudflare API Request unsuccessful. GET https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_EXTERNAL/rulesets failed."
        exit 1
    fi
    RULESET_ID="$(jq -r '.result[] | select(.phase == "http_request_dynamic_redirect") | .id' <<<"${API_LIST_RULESETS_ZONE_EXTERNAL}")"
    if [[ -n "${RULESET_ID}" ]]; then
        RESPONSE="$(curl -s https://api.cloudflare.com/client/v4/zones/"${CLOUDFLARE_ZONE_ID_EXTERNAL}"/rulesets/"${RULESET_ID}" -X PUT -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_1}" --json "${JSON_REDIRECT_RULESET_EXTERNAL}")"
        if ! jq -e ".success" <<<"${RESPONSE}" >/dev/null 2>&1; then
            echo "ERROR: Cloudflare API Request unsuccessful. PUT https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_EXTERNAL/rulesets/RULESET_ID failed."
            exit 1
        fi
        echo "Cloudflare API Request successful. PUT https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_IDS_EXTERNAL/rulesets/RULESET_ID succeeded."
    else
        RESPONSE="$(curl -s https://api.cloudflare.com/client/v4/zones/"${CLOUDFLARE_ZONE_ID_EXTERNAL}"/rulesets -X POST -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_1}" --json "${JSON_REDIRECT_RULESET_EXTERNAL}")"
        if ! jq -e ".success" <<<"${RESPONSE}" >/dev/null 2>&1; then
            echo "ERROR: Cloudflare API Request unsuccessful. POST https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_EXTERNAL/rulesets failed."
            exit 1
        fi
        echo "Cloudflare API Request successful. POST https://api.cloudflare.com/client/v4/zones/CLOUDFLARE_ZONE_ID_EXTERNAL/rulesets succeeded."
    fi
done
