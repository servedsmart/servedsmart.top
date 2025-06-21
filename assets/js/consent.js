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
function setConsentValueStorage(hashes, consentValue) {
  localStorage.setItem("optional-script-hashes", hashes.toString());
  localStorage.setItem("consent-settings", consentValue);
}
// Calculate consentValue, string should be either "0" or "1"
function getConsentValue(scripts, string) {
  return scripts.map(() => string).join("");
}
// Get stored consentValue from localStorage or remove if hashes don't match
function getConsentValueFromStorage(hashes) {
  const storedScriptHashes = localStorage.getItem("optional-script-hashes");
  if (storedScriptHashes === hashes.toString()) {
    return localStorage.getItem("consent-settings");
  } else {
    localStorage.removeItem("optional-script-hashes");
    localStorage.removeItem("consent-settings");
    return null;
  }
}
// Get consent value from checkboxes
function getConsentValueFromCheckboxes() {
  const elements = document.querySelectorAll("#consent-overlay input:not([disabled])");
  return Array.from(elements)
    .map((element) => (element.checked ? "1" : "0"))
    .join("");
}

// Set checkboxes from consentValue
function setCheckboxes(consentValue) {
  const elements = document.querySelectorAll("#consent-overlay input:not([disabled])");
  elements.forEach((element, index) => (element.checked = consentValue[index] === "1"));
}
// Set all elements unchecked
function setUnchecked(elements) {
  elements.forEach((element) => (element.checked = false));
}

// Activate element and parentElement
function activateWithParent(element) {
  element.classList.remove("hidden");
  element.classList.add("flex");
  element.parentElement.classList.add("flex");
  element.parentElement.classList.remove("hidden");
}
// Deactivate element and parentElement
function deactivateWithParent(element) {
  element.classList.add("hidden");
  element.classList.remove("flex");
  element.parentElement.classList.add("hidden");
  element.parentElement.classList.remove("flex");
  window.location.hash = "#consent-exit";
}

// Load javascript
function loadScripts(scripts, hashes, consentValue) {
  const documentScripts = Array.from(document.querySelectorAll("script")).map((scr) => scr.src);
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
function loadFunctionalScripts(scripts, hashes) {
  const consentValue = getConsentValue(scripts, "1");
  loadScripts(scripts, hashes, consentValue);
}
// Load optional javascript
function loadOptionalScripts(scripts, hashes, consentValue) {
  deactivateWithParent(document.getElementById("consent-notice"));
  deactivateWithParent(document.getElementById("consent-overlay"));
  if (!consentValue) {
    setConsentValueStorage(hashes, "0");
    return;
  }
  setCheckboxes(consentValue);
  setConsentValueStorage(hashes, consentValue);
  loadScripts(scripts, hashes, consentValue);
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

// Get values as array from HTML data-
function splitAttribute(function_) {
  return consentScriptElement && function_() ? function_().split(" ") : [];
}

const consentScriptElement = document.currentScript;

waitForReadyState(() => {
  // Set variables containing scripts and hashes
  const functionalScripts = splitAttribute(() => {
    return consentScriptElement.getAttribute("data-functional-scripts");
  });
  const functionalScriptHashes = splitAttribute(() => {
    return consentScriptElement.getAttribute("data-functional-script-hashes");
  });
  const optionalScripts = splitAttribute(() => {
    return consentScriptElement.getAttribute("data-optional-scripts");
  });
  const optionalScriptHashes = splitAttribute(() => {
    return consentScriptElement.getAttribute("data-optional-script-hashes");
  });

  // Load functional javascript
  loadFunctionalScripts(functionalScripts, functionalScriptHashes);

  // Uncheck checkboxes
  setUnchecked(document.querySelectorAll("#consent-overlay input:not([disabled])"));

  // Load javascript if user has consented or show notice
  const consentValue = getConsentValueFromStorage(optionalScriptHashes);
  if (consentValue) {
    setCheckboxes(consentValue);
    loadScripts(optionalScripts, optionalScriptHashes, consentValue);
  } else {
    activateWithParent(document.getElementById("consent-notice"));
  }
  // Handle consent buttons
  addClickExec(document.querySelectorAll(".consent-button-reject-all"), () => {
    const consentValue = getConsentValue(optionalScripts, "0");
    loadOptionalScripts(optionalScripts, optionalScriptHashes, consentValue);
  });
  addClickExec(document.querySelectorAll(".consent-button-accept-all"), () => {
    const consentValue = getConsentValue(optionalScripts, "1");
    loadOptionalScripts(optionalScripts, optionalScriptHashes, consentValue);
  });
  addClickExec(document.querySelectorAll(".consent-button-settings"), () => {
    window.location.href = "#consent-overlay";
  });
  addClickExec(document.querySelectorAll(".consent-button-confirm"), () => {
    // Get value of checkboxes
    const consentValue = getConsentValueFromCheckboxes();
    loadOptionalScripts(optionalScripts, optionalScriptHashes, consentValue);
  });
  addClickExec(document.getElementById("consent-overlay-container"), (event) => {
    const element = document.getElementById("consent-overlay");
    if (!element.contains(event.target)) {
      deactivateWithParent(element);
    }
  });

  // Set consent-exit hash if in consent-overlay
  if (window.location.hash === "#consent-overlay") {
    window.location.hash = "#consent-exit";
  }

  // Open consent-overlay if hash is #consent-overlay
  window.onhashchange = () => {
    if (window.location.hash === "#consent-overlay") {
      const element = document.getElementById("consent-overlay");
      activateWithParent(element);
      // FIXME: Move this to consent.html as max-h-[100vh], currently I don't want to maintain a custom compiled/main.css
      element.style.maxHeight = "100vh";
    }
  };
});
