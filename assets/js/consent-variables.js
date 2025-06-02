/*
 * File: consent-variables.js
 * Author: Leopold Meinel (leo@meinel.dev)
 * -----
 * Copyright (c) 2025 Leopold Meinel & contributors
 * SPDX ID: MIT
 * URL: https://opensource.org/licenses/MIT
 * -----
 */
const optionalScripts = [];
const optionalScriptHashes = [];
const functionalScripts = [];
const functionalScriptHashes = [];
{{- $currentLang := $.Site.Language.Lang -}}
{{- range index $.Site.Data $currentLang "consent" "items" -}}
    {{- if .script_file -}}
        {{- $script_file := resources.Get (printf "js/%s" .script_file) | resources.ExecuteAsTemplate (printf "js/%s" .script_file) . | resources.Minify | resources.Fingerprint (.Site.Params.fingerprintAlgorithm | default "sha512") -}}
        {{- if .is_functional -}}
            functionalScripts.push("{{- $script_file.RelPermalink -}}");
            functionalScriptHashes.push("{{- $script_file.Data.Integrity -}}");
        {{- else -}}
            optionalScripts.push("{{- $script_file.RelPermalink -}}");
            optionalScriptHashes.push("{{- $script_file.Data.Integrity -}}");
        {{- end -}}
    {{- end -}}
{{- end -}}
