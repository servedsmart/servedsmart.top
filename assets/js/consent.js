/*
 * File = consent.js
 * Author = Leopold Meinel (leo@meinel.dev)
 * -----
 * Copyright (c) 2025 Leopold Meinel & contributors
 * SPDX ID = MIT
 * URL = https://opensource.org/licenses/MIT
 * -----
 */

// Set localStorage
function setLocalStorage(consentValue) {
  localStorage.setItem("optional-scripts", optionalScripts.toString());
  localStorage.setItem("consent-settings", consentValue);
}
// Get from localStorage and remove if optionalScripts don't match
function getLocalStorageOrRemove() {
  if (localStorage.getItem("optional-scripts") === optionalScripts.toString()) {
    return localStorage.getItem("consent-settings");
  } else {
    localStorage.removeItem("optional-scripts");
    localStorage.removeItem("consent-settings");
    return null;
  }
}
// Modify all consent scripts, string should be either "0" or "1"
function modifyAllConsent(scripts, string) {
  let consentValue = "";
  scripts.forEach(() => {
    consentValue = consentValue + string;
  });
  loadOptionalJS(consentValue);
}
// Load optional javascript
function loadOptionalJS(consentValue) {
  deactivateWithParent(document.getElementById("consent-notice"));
  deactivateWithParent(document.getElementById("consent-overlay"));
  if (!consentValue) {
    setLocalStorage("0");
    return;
  }
  setConsentInputs(consentValue);
  setLocalStorage(consentValue);
  loadJS(optionalScripts, consentValue);
}
// Load funcional javascript
function loadFunctionalJS() {
  let consentValue = "";
  functionalScripts.forEach(() => {
    consentValue = consentValue + "1";
  });
  loadJS(functionalScripts, consentValue);
}
// Load javascript
function loadJS(scripts, consentValue) {
  const documentScripts = Array.from(document.querySelectorAll("script")).map(
    (scr) => scr.src
  );
  scripts.forEach((value, key) => {
    if (
      documentScripts.includes(value) ||
      documentScripts.includes(window.location.origin + value)
    ) {
      return;
    }
    if (consentValue[key] === "1") {
      let script = document.createElement("script");
      script.type = "text/javascript";
      script.src = value;
      document.body.appendChild(script);
    }
  });
}
// Set consent value via checkboxes
function setConsentInputs(consentValue) {
  const elements = document.querySelectorAll(
    "#consent-overlay input:not([disabled])"
  );
  elements.forEach(function (element, index) {
    if (consentValue[index] === "1") element.checked = true;
    else element.checked = false;
  });
}
// Set consent value from checkboxes
function setConsentValue() {
  const elements = document.querySelectorAll(
    "#consent-overlay input:not([disabled])"
  );
  let consentValue = "";
  elements.forEach(function (element) {
    if (element.checked) consentValue = consentValue + "1";
    else consentValue = consentValue + "0";
  });
  document.getElementById("consent-settings-confirm").dataset.consentvalue =
    consentValue;
}
// Set all elements unchecked
function setUnchecked(elements) {
  elements.forEach((element) => {
    element.checked = false;
  });
}
// Handle event listeners on click for elements
function addClickExec(elements, fn) {
  elements.forEach((element) => {
    element.addEventListener("click", fn);
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
if (getLocalStorageOrRemove()) {
  const consentValue = getLocalStorageOrRemove();
  setConsentInputs(consentValue);
  loadJS(optionalScripts, consentValue);
} else {
  activateWithParent(document.getElementById("consent-notice"));
}
// Handle consent buttons
addClickExec(document.querySelectorAll(".consent-settings"), () => {
  window.location.href = "#consent-overlay";
});
addClickExec(document.querySelectorAll(".consent-reject-optional"), () => {
  modifyAllConsent(optionalScripts, "0");
});
addClickExec(document.querySelectorAll(".consent-accept-all"), () => {
  modifyAllConsent(optionalScripts, "1");
});
document
  .getElementById("consent-settings-confirm")
  .addEventListener("click", (event) => {
    setConsentValue();
    loadOptionalJS(event.currentTarget.dataset.consentvalue);
  });
// Remove active attribute if clicking outside of div
document
  .getElementById("consent-overlay")
  .addEventListener("click", (event) => {
    if (
      !document.querySelector("#consent-overlay > div").contains(event.target)
    ) {
      deactivateWithParent(event.currentTarget);
    }
  });
