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
get_hashes_inline() {
    for content_ in "${CONTENTS[@]}"; do
        content="$(printf "%b\n" "${content_}")"
        printf '%s\n' "'sha256-$(printf '%s\n' "$(printf '%s' "${content}" | openssl sha256 -binary | openssl base64 -A)'")"
    done
}
get_hashes_files() {
    pattern="${1}"
    while IFS= read -r file; do
        printf '%s\n' "'sha256-$(printf '%s\n' "$(openssl sha256 -binary "${file}" | openssl base64 -A)'")"
    done < <(find "${tmp_dir}"/public -type f -name "${pattern}")
}
set_hashes() {
    ## Get content of tags as array
    type="${1}"
    if [[ "${type}" == "script" ]]; then
        selectors=("${type}" "${type}" "text")
    elif [[ "${type}" == "style" ]]; then
        selectors=("[${type}]" "${type}" "${type}")
    fi
    target_branch="${2}"
    JSON_CONTENT=""
    while IFS= read -r file; do
        JSON_CONTENT+="$(pup -f "${file}" "${selectors[0]} json{}")"
    done < <(grep -rl --include="*.html" "${selectors[1]}" "${tmp_dir}"/public)
    JSON_CONTENT="$(printf '%s\n' "${JSON_CONTENT}" | jq -Scs "add | [ .. | select(type == \"object\" and has(\"${selectors[2]}\")) ] | unique_by(.${selectors[2]}) | map(.${selectors[2]})")"
    readarray -t CONTENTS < <(jq -r '.[] | gsub("\n"; "\\n")' <<<"${JSON_CONTENT}")
    ## Get HASHES and add to either SCRIPT_HASHES or STYLE_HASHES
    HASHES=()
    readarray -t HASHES_ < <(get_hashes_inline)
    if [[ "${type}" == "script" ]]; then
        readarray -t HASHES < <(get_hashes_files "*.js")
        HASHES+=("${HASHES_[@]}")
        SCRIPT_HASHES["${target_branch}"]="${HASHES[*]}"
    elif [[ "${type}" == "style" ]]; then
        HASHES+=("${HASHES_[@]}")
        STYLE_HASHES["${target_branch}"]="${HASHES[*]}"
    fi
}
set_unique_script_hashes() {
    ## Remove duplicates
    target_branch="${1}"
    IFS=' ' read -r -a SCRIPT_HASHES_ <<<"${SCRIPT_HASHES["${target_branch}"]}"
    declare -A SCRIPT_HASHES__
    for hash in "${SCRIPT_HASHES_[@]}"; do
        SCRIPT_HASHES__["${hash}"]=1
    done
    SCRIPT_HASHES["${target_branch}"]="${!SCRIPT_HASHES__[*]}"
}
set_unique_style_hashes() {
    ## Remove duplicates
    target_branch="${1}"
    IFS=' ' read -r -a STYLE_HASHES_ <<<"${STYLE_HASHES["${target_branch}"]}"
    declare -A STYLE_HASHES__
    for hash in "${STYLE_HASHES_[@]}"; do
        STYLE_HASHES__["${hash}"]=1
    done
    STYLE_HASHES["${target_branch}"]="${!STYLE_HASHES__[*]}"
}
## Get SCRIPT_HASHES and STYLE_HASHES for every branch
declare -A SCRIPT_HASHES
declare -A STYLE_HASHES
### Get hashes for main
hugo --enableGitInfo --minify -e "production" -d "${tmp_dir}"/public
rm -f "${tmp_dir}"/public/js/edit-cms-sveltia*
set_hashes "script" "main"
set_unique_script_hashes "main"
set_hashes "style" "main"
set_unique_style_hashes "main"
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
readarray -t TARGET_BRANCHES < <(git for-each-ref --format='%(refname:short)' refs/heads)
for target_branch in "${TARGET_BRANCHES[@]}"; do
    #### Build current branch if not main
    if [[ "${target_branch}" == "main" ]]; then
        continue
    fi
    git restore .
    git clean -fdx
    git switch --recurse-submodules "${target_branch}"
    hugo --enableGitInfo --minify -e "production" -d "${tmp_dir}"/public
    rm -f "${tmp_dir}"/public/js/edit-cms-sveltia*
    #### Get hashes
    set_hashes "script" "${target_branch}"
    set_unique_script_hashes "${target_branch}"
    set_hashes "style" "${target_branch}"
    set_unique_style_hashes "${target_branch}"
done
## Restore and switch back to main
git restore .
git clean -fdx
git switch --recurse-submodules "main"

## https://content-security-policy.com/
### Create a default csp for every target_branch
declare -A CSP_DEFAULT
for target_branch in "${TARGET_BRANCHES[@]}"; do
    RULES_CSP_DEFAULT=(
        "default-src 'none'"
        # FIXME: Uncomment below after CSP is working correctly. I think all scripts are loaded correctly with hashes. CSP is too long, it seems like Cloudflare has a 4k char limit or maybe 8k+ bytes.
        # FIXME: Wait for https://github.com/nunocoracao/blowfish/pull/2194
        # FIXME: See: https://github.com/nunocoracao/blowfish/discussions/2198
        #"script-src 'self' 'strict-dynamic' ${SCRIPT_HASHES["${target_branch}"]}"
        "script-src 'self' 'unsafe-inline'"
        # FIXME: Uncomment below after CSP is working correctly. CSP is too long, it seems like Cloudflare has a 4k char limit or maybe 8k+ bytes.
        # FIXME: Wait for https://github.com/nunocoracao/blowfish/pull/2196
        # FIXME: See: https://github.com/nunocoracao/blowfish/discussions/2198
        #"style-src 'self' 'unsafe-hashes' ${STYLE_HASHES["${target_branch}"]}"
        "style-src 'self' 'unsafe-inline'"
        "img-src 'self' blob: data:"
        "object-src 'none'"
        "media-src 'self'"
        "frame-src 'self' https://www.youtube-nocookie.com"
        "child-src 'self' https://www.youtube-nocookie.com"
        "form-action 'self'"
        "frame-ancestors 'none'"
        "manifest-src 'self'"
        "base-uri 'self'"
        "upgrade-insecure-requests"
    )
    RULES_CSP_DEFAULT_LENGTH="${#RULES_CSP_DEFAULT[@]}"
    for ((i = 0; i < RULES_CSP_DEFAULT_LENGTH; i++)); do
        if ((i != RULES_CSP_DEFAULT_LENGTH - 1)); then
            #### Join into string
            CSP_DEFAULT["${target_branch}"]+="${RULES_CSP_DEFAULT[${i}]}; "
            continue
        fi
        #### Join into string
        CSP_DEFAULT["${target_branch}"]+="${RULES_CSP_DEFAULT[${i}]}"
    done
done
### https://github.com/sveltia/sveltia-cms?tab=readme-ov-file#setting-up-content-security-policy
RULES_CSP_CMS=(
    "default-src 'none'"
    "script-src 'self' https://unpkg.com"
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com"
    "img-src 'self' blob: data: https://*.githubusercontent.com"
    "object-src 'none'"
    "media-src blob:"
    "frame-src blob: https://www.youtube-nocookie.com"
    "child-src blob: https://www.youtube-nocookie.com"
    "form-action 'self'"
    "frame-ancestors 'none'"
    "manifest-src 'self'"
    "base-uri 'self'"
    "upgrade-insecure-requests"
    "font-src 'self' https://fonts.gstatic.com"
    "connect-src 'self' blob: data: https://unpkg.com https://api.github.com https://www.githubstatus.com"
)
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
JSON_RESPONSE_HEADER_TRANSFORM_RULESET="$(
    cat <<EOF | jq -c
{
  "name": "HTTP Response Headers",
  "description": "Generated by ${REPO_URL}",
  "kind": "zone",
  "phase": "http_response_headers_transform",
  "rules": [
    {
      "expression": "${EXPRESSION_CMS}",
      "description": "HTTP Response Headers for edit-cms",
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
for target_branch in "${TARGET_BRANCHES[@]}"; do
    if [[ "${target_branch}" == "main" ]]; then
        DOMAIN_DEFAULT="${TARGET_DOMAIN}"
        EXPRESSION_DEFAULT="(http.host eq \\\"${DOMAIN_DEFAULT}\\\")"
    else
        DOMAIN_DEFAULT="${target_branch}.${TARGET_DOMAIN}"
        #### FIXME: This should also allow custom domains that are not equivalent to the branch, but I don't need that for now.
        EXPRESSION_DEFAULT="(http.host eq \\\"${target_branch}.${TARGET_DOMAIN}\\\")"
    fi
    JSON_CSP_RULE="$(
        cat <<EOF | jq -c
{
  "expression": "${EXPRESSION_DEFAULT}",
  "description": "HTTP Response Headers for ${DOMAIN_DEFAULT}",
  "action": "rewrite",
  "action_parameters": {
    "headers": {
      "Content-Security-Policy": {
        "operation": "set",
        "value": "${CSP_DEFAULT["${target_branch}"]}"
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
}
EOF
    )"
    JSON_RESPONSE_HEADER_TRANSFORM_RULESET="$(jq -c --argjson json_csp_rule "${JSON_CSP_RULE}" '.rules |= [ $json_csp_rule ] + .' <<<"${JSON_RESPONSE_HEADER_TRANSFORM_RULESET}")"
done
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
