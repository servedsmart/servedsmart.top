/*
 * File: consent.js
 * Author: Leopold Meinel (leo@meinel.dev)
 * -----
 * Copyright (c) 2025 Leopold Meinel & contributors
 * SPDX ID: MIT
 * URL: https://opensource.org/licenses/MIT
 * -----
 */

// Based on: https://hugocodex.org/add-ons/cookie-consent/#manage-consent

// Wait for readyState
function waitForReadyState(function_) {
  if (["interactive", "complete"].includes(document.readyState)) {
    function_();
  } else {
    window.addEventListener("DOMContentLoaded", function handler() {
      function_();
      document.removeEventListener("DOMContentLoaded", handler);
    });
  }
}

// Store consentValue in localStorage
function setConsentValueStorage(consentValue) {
  localStorage.setItem(
    "optional-script-hashes",
    optionalScriptHashes.toString()
  );
  localStorage.setItem("consent-settings", consentValue);
}
// Calculate consentValue, string should be either "0" or "1"
function getConsentValue(scripts, string) {
  return scripts.map(() => string).join("");
}
// Get stored consentValue from localStorage or remove if optionalScripts don't match
function getConsentValueFromStorage() {
  const storedScriptHashes = localStorage.getItem("optional-script-hashes");
  if (storedScriptHashes === optionalScriptHashes.toString()) {
    return localStorage.getItem("consent-settings");
  } else {
    localStorage.removeItem("optional-script-hashes");
    localStorage.removeItem("consent-settings");
    return null;
  }
}
// Get consent value from checkboxes
function getConsentValueFromCheckboxes() {
  const elements = document.querySelectorAll(
    "#consent-overlay input:not([disabled])"
  );
  return Array.from(elements)
    .map((element) => (element.checked ? "1" : "0"))
    .join("");
}

// Set checkboxes from consentValue
function setCheckboxes(consentValue) {
  const elements = document.querySelectorAll(
    "#consent-overlay input:not([disabled])"
  );
  elements.forEach(
    (element, index) => (element.checked = consentValue[index] === "1")
  );
}
// Set all elements unchecked
function setUnchecked(elements) {
  elements.forEach((element) => (element.checked = false));
}

// Activate element and parentElement
function activateWithParent(element) {
  element.classList.add("active");
  element.parentElement.classList.add("active");
}
// Deactivate element and parentElement
function deactivateWithParent(element) {
  element.classList.remove("active");
  element.parentElement.classList.remove("active");
  window.location.hash = "#consent-exit";
}

// Load javascript
function loadScripts(scripts, hashes, consentValue) {
  const documentScripts = Array.from(document.querySelectorAll("script")).map(
    (scr) => scr.src
  );
  scripts.forEach((value, key) => {
    if (
      !documentScripts.includes(value) &&
      !documentScripts.includes(window.location.origin + value) &&
      consentValue[key] === "1"
    ) {
      const script = document.createElement("script");
      script.type = "text/javascript";
      script.src = value;
      script.integrity = hashes[key];
      document.body.appendChild(script);
    }
  });
}
// Load functional javascript
function loadFunctionalScripts() {
  const consentValue = getConsentValue(functionalScripts, "1");
  loadScripts(functionalScripts, functionalScriptHashes, consentValue);
}
// Load optional javascript
function loadOptionalScripts(consentValue) {
  deactivateWithParent(document.getElementById("consent-notice"));
  deactivateWithParent(document.getElementById("consent-overlay"));
  if (!consentValue) {
    setConsentValueStorage("0");
    return;
  }
  setCheckboxes(consentValue);
  setConsentValueStorage(consentValue);
  loadScripts(optionalScripts, optionalScriptHashes, consentValue);
}

// Handle event listeners on click for elements
function addClickExec(elements, function_) {
  if (elements instanceof HTMLElement) {
    elements = [elements];
  }
  elements.forEach((element) => {
    element.addEventListener("click", function_);
  });
}

const optionalScripts = [];
const optionalScriptHashes = [];
const functionalScripts = [];
const functionalScriptHashes = [];
{{- $currentLang := $.Site.Language.Lang -}}
{{- range index $.Site.Data $currentLang "consent" "items" -}}
    {{- if .scriptFile -}}
        {{- $scriptFile := resources.Get .scriptFile -}}
        {{- $scriptFile = $scriptFile | resources.ExecuteAsTemplate .scriptFile . | resources.Minify | resources.Fingerprint (.Site.Params.fingerprintAlgorithm | default "sha512") -}}
        {{- if .isFunctional -}}
            functionalScripts.push("{{- $scriptFile.RelPermalink -}}");
            functionalScriptHashes.push("{{- $scriptFile.Data.Integrity -}}");
        {{- else -}}
            optionalScripts.push("{{- $scriptFile.RelPermalink -}}");
            optionalScriptHashes.push("{{- $scriptFile.Data.Integrity -}}");
        {{- end -}}
    {{- end -}}
{{- end -}}

waitForReadyState(() => {
  // Load functional javascript
  loadFunctionalScripts();

  // Uncheck checkboxes
  setUnchecked(
    document.querySelectorAll("#consent-overlay input:not([disabled])")
  );

  // Load javascript if user has consented or show notice
  const consentValue = getConsentValueFromStorage();
  if (consentValue) {
    setCheckboxes(consentValue);
    loadScripts(optionalScripts, optionalScriptHashes, consentValue);
  } else {
    activateWithParent(document.getElementById("consent-notice"));
  }
  // Handle consent buttons
  addClickExec(document.querySelectorAll(".consent-reject-optional"), () => {
    const consentValue = getConsentValue(optionalScripts, "0");
    loadOptionalScripts(consentValue);
  });
  addClickExec(document.querySelectorAll(".consent-accept-all"), () => {
    const consentValue = getConsentValue(optionalScripts, "1");
    loadOptionalScripts(consentValue);
  });
  addClickExec(document.getElementById("consent-settings"), () => {
    window.location.href = "#consent-overlay";
  });
  addClickExec(document.getElementById("consent-settings-confirm"), (event) => {
    // Get value of checkboxes
    const consentValue = getConsentValueFromCheckboxes();
    loadOptionalScripts(consentValue);
  });
  addClickExec(document.getElementById("consent-overlay"), (event) => {
    if (
      !document.querySelector("#consent-overlay > div").contains(event.target)
    ) {
      deactivateWithParent(event.currentTarget);
    }
  });

  // Set consent-exit hash if in consent-overlay
  if (window.location.hash === "#consent-overlay") {
    window.location.hash = "#consent-exit";
  }

  // Open consent-overlay if hash is #consent-overlay
  window.onhashchange = () => {
    if (window.location.hash === "#consent-overlay") {
      activateWithParent(document.getElementById("consent-overlay"));
    }
  };
});
