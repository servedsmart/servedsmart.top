/*
 * File: consent.js
 * Author: Leopold Meinel (leo@meinel.dev)
 * -----
 * Copyright (c) 2025 Leopold Meinel & contributors
 * SPDX ID: MIT
 * URL: https://opensource.org/licenses/MIT
 * -----
 */

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
// Set localStorage
function setLocalStorage(consentValue) {
  localStorage.setItem("optional-scripts", optionalScripts.toString());
  localStorage.setItem("consent-settings", consentValue);
}
// Get from localStorage or remove if optionalScripts don't match
function getLocalStorageOrRemove() {
  const storedScripts = localStorage.getItem("optional-scripts");
  if (storedScripts === optionalScripts.toString()) {
    return localStorage.getItem("consent-settings");
  } else {
    localStorage.removeItem("optional-scripts");
    localStorage.removeItem("consent-settings");
    return null;
  }
}
// Calculate consentValue, string should be either "0" or "1"
function getConsentValue(scripts, string) {
  return scripts.map(() => string).join("");
}
// Load optional javascript
function loadOptionalJS(consentValue) {
  deactivateWithParent(document.getElementById("consent-notice"));
  deactivateWithParent(document.getElementById("consent-overlay"));
  if (!consentValue) {
    setLocalStorage("0");
    return;
  }
  setCheckboxes(consentValue);
  setLocalStorage(consentValue);
  loadJS(optionalScripts, consentValue);
}
// Load functional javascript
function loadFunctionalJS() {
  const consentValue = getConsentValue(functionalScripts, "1");
  loadJS(functionalScripts, consentValue);
}
// Load javascript
function loadJS(scripts, consentValue) {
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
      document.body.appendChild(script);
    }
  });
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
// Set consent value from checkboxes
function setConsentValue() {
  const elements = document.querySelectorAll(
    "#consent-overlay input:not([disabled])"
  );
  const consentValue = Array.from(elements)
    .map((element) => (element.checked ? "1" : "0"))
    .join("");
  document.getElementById("consent-settings-confirm").dataset.consentvalue =
    consentValue;
}
// Set all elements unchecked
function setUnchecked(elements) {
  elements.forEach((element) => (element.checked = false));
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

waitForReadyState(() => {
  // Set empty hash if in consent-overlay
  if (window.location.hash === "#consent-overlay") {
    window.location.hash = "#consent-exit";
  }

  // Load functional javascript
  loadFunctionalJS();

  // Uncheck checkboxes
  setUnchecked(
    document.querySelectorAll("#consent-overlay input:not([disabled])")
  );

  // Open consent-overlay if hash is #consent-overlay
  window.onhashchange = () => {
    if (window.location.hash === "#consent-overlay") {
      activateWithParent(document.getElementById("consent-overlay"));
    }
  };

  // Load javascript if user has consented or show notice
  const consentValue = getLocalStorageOrRemove();
  if (consentValue) {
    setCheckboxes(consentValue);
    loadJS(optionalScripts, consentValue);
  } else {
    activateWithParent(document.getElementById("consent-notice"));
  }
  // Handle consent buttons
  addClickExec(document.querySelectorAll(".consent-reject-optional"), () => {
    const consentValue = getConsentValue(optionalScripts, "0");
    loadOptionalJS(consentValue);
  });
  addClickExec(document.querySelectorAll(".consent-accept-all"), () => {
    const consentValue = getConsentValue(optionalScripts, "1");
    loadOptionalJS(consentValue);
  });
  addClickExec(document.getElementById("consent-settings"), () => {
    window.location.href = "#consent-overlay";
  });
  addClickExec(document.getElementById("consent-settings-confirm"), (event) => {
    setConsentValue();
    loadOptionalJS(event.currentTarget.dataset.consentvalue);
  });
  addClickExec(document.getElementById("consent-overlay"), (event) => {
    if (
      !document.querySelector("#consent-overlay > div").contains(event.target)
    ) {
      deactivateWithParent(event.currentTarget);
    }
  });
});
