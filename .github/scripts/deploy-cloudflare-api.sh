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
tmp_dir="$(mktemp -d /tmp/site-XXXXXX)"
cp -R "${SCRIPT_DIR}"/../.. "${tmp_dir}"
cd "${tmp_dir}"

# Response Header Transform Rules
# FIXME: Some inline scripts are apparently created in index.js, not sure how we can fix that since they are generated dynamically...
# FIXME: styles is empty all the time but I'm pretty sure that there are a lot of inline styles that should get matched here
tag_content_hashes_update() {
    ## Get content of tags as array
    TAG_TYPE="${1}"
    TARGET_BRANCH="${2}"
    TAG_CONTENT=""
    while IFS= read -r file; do
        TAG_CONTENT+="$(pup -f "${file}" "${TAG_TYPE} json{}")"
    done < <(grep -rl --include="*.html" "${TAG_TYPE}" "${tmp_dir}"/public)
    TAG_CONTENT_JSON="$(printf '%s\n' "${TAG_CONTENT}" | jq -Scs 'add | map(select(has("text"))) | unique_by(.text) | map(.text)')"
    readarray -t TAG_CONTENTS < <(jq -r '.[] | gsub("\n"; "\\n")' <<<"${TAG_CONTENT_JSON}")
    ## Get TAG_CONTENT_HASHES from TAG_CONTENTS
    TAG_CONTENT_HASHES=()
    for tag_content_ in "${TAG_CONTENTS[@]}"; do
        tag_content="$(printf "%b\n" "${tag_content_}")"
        TAG_CONTENT_HASHES+=("'sha256-$(printf '%s\n' "$(printf '%s' "${tag_content}" | openssl sha256 -binary | openssl base64)'")")
    done
    if [[ "${TAG_TYPE}" == "script" ]]; then
        SCRIPT_HASHES["${TARGET_BRANCH}"]="${TAG_CONTENT_HASHES[*]}"
    elif [[ "${TAG_TYPE}" == "style" ]]; then
        STYLE_HASHES["${TARGET_BRANCH}"]="${TAG_CONTENT_HASHES[*]}"
    fi
}
script_hashes_remove_duplicates() {
    ## Remove duplicates
    TARGET_BRANCH="${1}"
    readarray -td' ' SCRIPT_HASHES_ <<<"${SCRIPT_HASHES["${TARGET_BRANCH}"]}"
    declare -A SCRIPT_HASHES__
    for hash in "${SCRIPT_HASHES_[@]}"; do
        SCRIPT_HASHES__["${hash}"]=1
    done
    SCRIPT_HASHES["${TARGET_BRANCH}"]="${!SCRIPT_HASHES__[*]}"
}
style_hashes_remove_duplicates() {
    ## Remove duplicates
    TARGET_BRANCH="${1}"
    readarray -td' ' STYLE_HASHES_ <<<"${STYLE_HASHES["${TARGET_BRANCH}"]}"
    declare -A STYLE_HASHES__
    for hash in "${STYLE_HASHES_[@]}"; do
        STYLE_HASHES__["${hash}"]=1
    done
    STYLE_HASHES["${TARGET_BRANCH}"]="${!STYLE_HASHES__[*]}"
}
## Get SCRIPT_HASHES and STYLE_HASHES for every branch
declare -A SCRIPT_HASHES
declare -A STYLE_HASHES
### Get hashes for main
hugo --enableGitInfo --minify -e "production" -d ./public
tag_content_hashes_update "script" "main"
script_hashes_remove_duplicates "main"
tag_content_hashes_update "style" "main"
style_hashes_remove_duplicates "main"
### Fetch remote branches and get hashes for each
git remote set-branches origin '*'
git fetch --depth=1
for target_branch in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin); do
    #### Track all remote branches if not main or HEAD
    if [[ "${target_branch}" == "origin/main" || "${target_branch}" == "origin" ]]; then
        continue
    fi
    git branch --track "${target_branch#origin/}" "$target_branch"
done
for target_branch in $(git for-each-ref --format='%(refname:short)' refs/heads); do
    #### Build current branch if not main
    if [[ "${target_branch}" == "main" ]]; then
        continue
    fi
    git restore .
    git switch --recurse-submodules "${target_branch}"
    hugo --enableGitInfo --minify -e "production" -d ./public
    #### Get hashes
    tag_content_hashes_update "script" "${target_branch}"
    script_hashes_remove_duplicates "${target_branch}"
    tag_content_hashes_update "style" "${target_branch}"
    style_hashes_remove_duplicates "${target_branch}"
done
## Restore and switch back to main
git restore .
git switch --recurse-submodules "main"

## https://content-security-policy.com/
## FIXME: This whole array will have to be reworked to match will have to use SCRIPT_HASHES["${TARGET_BRANCH}"] and STYLE_HASHES["${TARGET_BRANCH}"]
RULES_CSP_DEFAULT=(
    "default-src 'none'"
    "script-src 'self' ${SCRIPT_HASHES[*]}"
    "style-src 'self' ${STYLE_HASHES[*]}"
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
DEFAULT_LOCALE="$(tomlq -cr ".defaultContentLanguage" "${tmp_dir}"/config/_default/hugo.toml)"
for file in "${tmp_dir}"/config/_default/languages.*.toml; do
    LOCALE="$(basename "${file}" .toml | cut -d. -f2)"
    if [[ "${LOCALE}" != "${DEFAULT_LOCALE}" ]]; then
        ### Append expression
        EXPRESSION_CMS+=" or (starts_with(http.request.uri.path, \\\"/${LOCALE}/edit-cms\\\"))"
    fi
done
## https://developers.cloudflare.com/ruleset-engine/rulesets-api/create/
### https://developers.cloudflare.com/rules/transform/response-header-modification/create-api/
### FIXME: This whole block will have to match a uri's domain and for each one, add the custom CSP accessible from an array that will have to be created
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
        echo "DEBUG: ${RESPONSE}"
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
