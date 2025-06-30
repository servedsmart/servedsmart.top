/*
 * File: ol-sp.js
 * Author: Leopold Meinel (leo@meinel.dev)
 * -----
 * Copyright (c) 2025 Leopold Meinel & contributors
 * SPDX ID: MIT
 * URL: https://opensource.org/licenses/MIT
 * -----
 */

(() => {
  const script = document.currentScript;

  const config = {
    mapId: script?.getAttribute("data-map-id"),
    centerControlId: script?.getAttribute("data-center-control-id"),
    centerControlButtonId: script?.getAttribute("data-center-control-button-id"),
    iconId: script?.getAttribute("data-icon-id"),
    popupId: script?.getAttribute("data-popup-id"),

    styleSheetHref: script?.getAttribute("data-style-sheet-href"),
    styleSheetHash: script?.getAttribute("data-style-sheet-hash"),

    extraCopyrightURL: script?.getAttribute("data-extra-copyright-url"),
    extraCopyrightName: script?.getAttribute("data-extra-copyright-name"),

    tileBaseURL: script?.getAttribute("data-tile-base-url"),

    height: script?.getAttribute("data-height"),
    width: script?.getAttribute("data-width"),

    centerX: parseFloat(script?.getAttribute("data-center-x")),
    centerY: parseFloat(script?.getAttribute("data-center-y")),
    zoom: parseInt(script?.getAttribute("data-zoom")),
    minZoom: parseInt(script?.getAttribute("data-min-zoom")),
    maxZoom: parseInt(script?.getAttribute("data-max-zoom")),

    pointX: parseFloat(script?.getAttribute("data-point-x")),
    pointY: parseFloat(script?.getAttribute("data-point-y")),

    iconSize: script?.getAttribute("data-icon-size"),
  };

  window.olSp(config);
})();
