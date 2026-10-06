/* SaúdeKonekta map — markers only (privacy: no patient data reaches here).
   Colours come from CSS design tokens so the map matches the rest of the UI. */
(function () {
  "use strict";
  var dataEl = document.getElementById("map-data");
  var mapEl = document.getElementById("map");
  if (!dataEl || !mapEl || typeof L === "undefined") return;

  var data = JSON.parse(dataEl.textContent);
  var css = getComputedStyle(document.documentElement);
  function token(name, fallback) {
    return (css.getPropertyValue(name) || fallback).trim() || fallback;
  }

  var map = L.map(mapEl).setView(data.center, data.zoom);

  // Satellite imagery = visualization layer (design §7). Failure is tolerated.
  var tileErrors = 0;
  var imagery = L.tileLayer(
    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
    {
      attribution: "Imagery © Esri, Maxar, Earthstar Geographics",
      maxZoom: 18,
    }
  );
  imagery.on("tileerror", function () {
    if (++tileErrors === 5) {
      var banner = document.getElementById("map-offline");
      if (banner) banner.hidden = false;
    }
  });
  imagery.addTo(map);

  var facilitiesLayer = L.layerGroup().addTo(map);
  var emergenciesLayer = L.layerGroup().addTo(map);

  var syncColors = {
    fresh: token("--text-success", "#047857"),
    stale: token("--text-warning", "#B45309"),
    never: token("--color-text-muted", "#6B7280"),
  };
  var severityColors = {
    LOW: token("--text-success", "#047857"),
    MEDIUM: token("--text-warning", "#B45309"),
    HIGH: token("--text-error", "#B91C1C"),
    CRITICAL: token("--color-emergency", "#DC2626"),
  };

  function esc(text) {
    var div = document.createElement("div");
    div.textContent = text == null ? "" : String(text);
    return div.innerHTML;
  }

  (data.facilities || []).forEach(function (f) {
    L.circleMarker([f.lat, f.lng], {
      radius: 7,
      color: token("--color-surface", "#FFFFFF"),
      weight: 2,
      fillColor: syncColors[f.sync] || syncColors.never,
      fillOpacity: 0.95,
    })
      .bindPopup(
        "<strong>" + esc(f.name) + "</strong><br>" +
        esc(f.type) + "<br>" +
        esc(f.municipality) + "<br>" +
        esc(data.sync_labels[f.sync] || f.sync)
      )
      .addTo(facilitiesLayer);

    if (f.active_emergencies > 0) {
      var color = severityColors[f.max_severity] || severityColors.HIGH;
      L.circleMarker([f.lat, f.lng], {
        radius: 13,
        color: color,
        weight: 3,
        fillColor: color,
        fillOpacity: 0.3,
      })
        .bindTooltip(String(f.active_emergencies))
        .addTo(emergenciesLayer);
    }
  });

  function bindToggle(buttonId, layer) {
    var button = document.getElementById(buttonId);
    if (!button) return;
    button.addEventListener("click", function () {
      var enabled = map.hasLayer(layer);
      if (enabled) {
        map.removeLayer(layer);
      } else {
        layer.addTo(map);
      }
      button.setAttribute("aria-pressed", enabled ? "false" : "true");
      button.classList.toggle("btn-primary", !enabled);
      button.classList.toggle("btn-outline-secondary", enabled);
    });
  }

  bindToggle("toggle-facilities", facilitiesLayer);
  bindToggle("toggle-emergencies", emergenciesLayer);
})();
