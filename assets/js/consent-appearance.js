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

var updateMeta = () => {
  var elem, style;
  elem = document.querySelector("body");
  style = getComputedStyle(elem);
  document.querySelector('meta[name="theme-color"]').setAttribute("content", style.backgroundColor);
};

{{ if and (.Site.Params.Logo) (.Site.Params.SecondaryLogo) }}
{{ $primaryLogo := resources.Get .Site.Params.Logo }}
{{ $secondaryLogo := resources.Get .Site.Params.SecondaryLogo }}
{{ if and ($primaryLogo) ($secondaryLogo) }}
var updateLogo = (targetAppearance) => {
  var imgElems = document.querySelectorAll("img.logo");
  var logoContainers = document.querySelectorAll("span.logo");

  targetLogoPath =
    targetAppearance == "{{ .Site.Params.DefaultAppearance }}"
      ? "{{ $primaryLogo.RelPermalink }}"
      : "{{ $secondaryLogo.RelPermalink }}";
  for (const elem of imgElems) {
    elem.setAttribute("src", targetLogoPath);
  }

  {{ if eq $primaryLogo.MediaType.SubType "svg" }}
  targetContent =
    targetAppearance == "{{ .Site.Params.DefaultAppearance }}"
      ? `{{ $primaryLogo.Content | safeHTML }}`
      : `{{ $secondaryLogo.Content | safeHTML }}`;
  for (const container of logoContainers) {
    container.innerHTML = targetContent;
  }
  {{ end }}
};
{{ end }}
{{- end }}

var getTargetAppearance = () => {
  return document.documentElement.classList.contains("dark") ? "dark" : "light";
};

// Usage
waitForReadyState(() => {
  const switcher = document.getElementById("appearance-switcher");
  const switcherMobile = document.getElementById("appearance-switcher-mobile");

  updateMeta();
  this.updateLogo?.(getTargetAppearance());

  if (switcher) {
    switcher.addEventListener("click", () => {
      document.documentElement.classList.toggle("dark");
      var targetAppearance = getTargetAppearance();
      localStorage.setItem("appearance", targetAppearance);
      updateMeta();
      this.updateLogo?.(targetAppearance);
    });
    switcher.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      localStorage.removeItem("appearance");
    });
  }
  if (switcherMobile) {
    switcherMobile.addEventListener("click", () => {
      document.documentElement.classList.toggle("dark");
      var targetAppearance = getTargetAppearance();
      localStorage.setItem("appearance", targetAppearance);
      updateMeta();
      this.updateLogo?.(targetAppearance);
    });
    switcherMobile.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      localStorage.removeItem("appearance");
    });
  }
});
