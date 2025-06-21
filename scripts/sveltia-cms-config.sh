#!/usr/bin/env bash
###
# File: sveltia-cms-config.sh
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

# Get site_url from config/_default/hugo.toml
site_url="$(tomlq -cr ".baseURL" "${SCRIPT_DIR}"/../config/_default/hugo.toml)"

# Get default_locale from config/_default/hugo.toml and locales from files in config/_default/languages.*.toml
default_locale="$(tomlq -cr ".defaultContentLanguage" "${SCRIPT_DIR}"/../config/_default/hugo.toml)"
LANGUAGE_FILES=("${SCRIPT_DIR}"/../config/_default/languages.*.toml)
for file in "${LANGUAGE_FILES[@]}"; do
    LOCALE="$(basename "${file}" .toml | cut -d. -f2)"
    LOCALES+=("${LOCALE}")
done
locales="$(jq -cn --args -- '$ARGS.positional' "${LOCALES[@]}")"

# Get language specific categories and tags from archetypes
ARCHETYPE_FILES=("${SCRIPT_DIR}"/../archetypes/external/*.md)
if [[ "${#ARCHETYPE_FILES[@]}" -ne "${#ARCHETYPE_FILES[@]}" ]]; then
    echo "ERROR: There is not the same number of language files as the number of archetype files."
    exit 1
fi
for file in "${ARCHETYPE_FILES[@]}"; do
    LOCALE="$(basename "${file}" .toml | cut -d. -f2)"
    for locale in "${LOCALES[@]}"; do
        if [[ "${locale}" == "${LOCALE}" ]]; then
            SUCCESS="true"
        fi
    done
    # Fail only if none of the commands have succeeded
    if [[ -z "${SUCCESS}" ]]; then
        echo "ERROR: Locale '${LOCALE}' from archetypes not found in languages."
        exit 1
    fi
    CONTENT="$(tr -d "+++" <"${file}" | tail -n +6)"
    case "${LOCALE}" in
    "de" | "en")
        # FIXME: After https://github.com/sveltia/sveltia-cms/issues/403 is resolved, use seperate categories for languages and translate them in config
        categories="$(
            {
                echo "${categories}"
                echo "${CONTENT}" | toml2json | jq -c '.categories'
            } | jq -cs '.[0] + .[1]'
        )"
        tags="$(
            {
                echo "${tags}"
                echo "${CONTENT}" | toml2json | jq -c '.tags'
            } | jq -cs '.[0] + .[1]'
        )"
        ;;
    *)
        echo "ERROR: Unchecked LOCALE: ${LOCALE}."
        exit 1
        ;;
    esac
done

# Convert toml to json
backend="$(toml2json "${SCRIPT_DIR}"/sveltia-cms-config/backend.toml | sed -E 's/"(\$\w+)"/\1/g')"
collections_template="$(toml2json "${SCRIPT_DIR}"/sveltia-cms-config/collections-template.toml | sed -E 's/"(\$\w+)"/\1/g')"
config="$(toml2json "${SCRIPT_DIR}"/sveltia-cms-config/config.toml | sed -E 's/"(\$\w+)"/\1/g')"
i18n="$(toml2json "${SCRIPT_DIR}"/sveltia-cms-config/i18n.toml | sed -E 's/"(\$\w+)"/\1/g')"
media_libraries="$(toml2json "${SCRIPT_DIR}"/sveltia-cms-config/media-libraries.toml | sed -E 's/"(\$\w+)"/\1/g')"
slug="$(toml2json "${SCRIPT_DIR}"/sveltia-cms-config/slug.toml | sed -E 's/"(\$\w+)"/\1/g')"

# Generate custom language specific entries in collections
for name in "${CONTENT_DIRS[@]}"; do
    collections_combined+="$(jq -cn "${collections_template}" --arg name "${name}" --arg label "${name^}" --arg folder "content/${name}" --argjson categories "${categories}" --argjson tags "${tags}")"
done
collections="$(
    {
        jq -cn '{ collections: [ inputs.collections ] | add }' <<<"${collections_combined}"
    } | jq -Scn '{ collections: [ inputs.collections ] | add }'
)"

# Combine everything into one file
{
    jq -cn --arg repo "${REPO}" --arg branch "${BRANCH}" --arg base_url "${BASE_URL}" "${backend}"
    jq -cn "${collections}"
    jq -cn --arg site_url "${site_url}" "${config}"
    jq -cn --arg default_locale "${default_locale}" --argjson locales "${locales}" "${i18n}"
    jq -cn "${media_libraries}"
    jq -cn "${slug}"
} | jq -Scs 'add' >"${SCRIPT_DIR}"/../assets/lib/sveltia-cms/sveltia-cms.json
