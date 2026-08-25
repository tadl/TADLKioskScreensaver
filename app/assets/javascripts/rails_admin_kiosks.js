(function () {
  function esc(s) {
    return String(s ?? "").replace(/[&<>"']/g, function (c) {
      return ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c];
    });
  }

  function fmtTime(t) {
    if (!t) return "";
    try { return new Date(t).toLocaleString(); } catch (e) { return String(t); }
  }

  function isUrl(s) {
    return typeof s === "string" && /^https?:\/\//i.test(s);
  }

  function linkify(url, label) {
    if (!isUrl(url)) return "";
    var text = label || url;
    return '<a href="' + esc(url) + '" target="_blank" rel="noopener">' + esc(text) + '</a>';
  }

  async function fetchHost(host) {
    var url = "/admin/kiosk_hosts/" + encodeURIComponent(host) + ".json";
    var resp = await fetch(url, { headers: { "Accept": "application/json" }, cache: "no-store" });
    if (!resp.ok) throw new Error("HTTP " + resp.status);
    return await resp.json();
  }

  function humanDuration(seconds) {
    seconds = Number(seconds);
    if (!Number.isFinite(seconds) || seconds <= 0) return "0s";

    var units = [
      ["d", 24 * 60 * 60],
      ["h", 60 * 60],
      ["m", 60],
      ["s", 1]
    ];

    var parts = [];
    units.forEach(function (unit) {
      var label = unit[0];
      var size = unit[1];
      if (seconds >= size) {
        var q = Math.floor(seconds / size);
        seconds = seconds % size;
        parts.push(q + label);
      }
    });
    return parts.join(" ");
  }

  function renderHeartbeat(hb) {
    if (!hb || !hb.kiosk_id) {
      return '<div class="text-muted mb-3">No heartbeat recorded for this host yet.</div>';
    }

    var lines = [];
    lines.push('<div><strong>Last seen:</strong> ' + esc(fmtTime(hb.last_seen_at)) + '</div>');
    if (hb.private_ip_address) {
      lines.push('<div><strong>Private IP:</strong> ' + esc(hb.private_ip_address) + '</div>');
    }
    lines.push('<div><strong>Uptime:</strong> ' + esc(humanDuration(hb.uptime_seconds)) + '</div>');
    lines.push('<div><strong>Kiosk service:</strong> ' + esc(hb.kiosk_service ?? "") + '</div>');
    lines.push('<div><strong>Chromium pids:</strong> ' + esc(hb.chromium_pids ?? "") + '</div>');

    if (hb.chromium_devtools_ok !== undefined && hb.chromium_devtools_ok !== null) {
      lines.push('<div><strong>DevTools OK:</strong> ' + esc(hb.chromium_devtools_ok) + '</div>');
    }
    if (hb.chromium_devtools_http) {
      lines.push('<div><strong>DevTools HTTP:</strong> ' + esc(hb.chromium_devtools_http) + '</div>');
    }
    if (hb.chromium_devtools_ms !== undefined && hb.chromium_devtools_ms !== null) {
      lines.push('<div><strong>DevTools ms:</strong> ' + esc(hb.chromium_devtools_ms) + '</div>');
    }

    return '<div class="mb-3"><h6 class="mb-2">Heartbeat</h6><div class="small">' + lines.join("") + '</div></div>';
  }

  function renderLogItem(l) {
    var level = (l.level || "").toString();
    var occurred = fmtTime(l.occurred_at);
    var levelClass = "bg-secondary";
    if (level === "error") levelClass = "bg-danger";
    else if (level === "warn" || level === "warning") levelClass = "bg-warning text-dark";
    else if (level === "info") levelClass = "bg-info text-dark";

    var kind = l.kind ? ('<span class="ms-2 text-muted">(' + esc(l.kind) + ')</span>') : "";
    var where = "";
    if (l.source || l.lineno || l.colno) {
      var parts = [];
      if (l.source) parts.push(esc(l.source));
      if (l.lineno) parts.push("line " + esc(l.lineno));
      if (l.colno) parts.push("col " + esc(l.colno));
      where = '<div class="text-muted small mt-1">' + parts.join(" &middot; ") + "</div>";
    }

    var links = [];
    if (l.tab_url) links.push("Tab: " + linkify(l.tab_url, "open"));
    if (l.href) links.push("Href: " + linkify(l.href, "open"));
    var linksHtml = links.length ? '<div class="small mt-1">' + links.join(" &nbsp; ") + "</div>" : "";

    var stackHtml = "";
    if (l.stack) {
      stackHtml =
        '<details class="mt-2">' +
          '<summary class="small">Stack trace</summary>' +
          '<pre class="mt-2 p-2 bg-light border rounded small" style="white-space:pre-wrap; max-height:300px; overflow:auto;">' +
            esc(l.stack) +
          '</pre>' +
        '</details>';
    }

    return (
      '<div class="list-group-item">' +
        '<div class="d-flex justify-content-between align-items-start">' +
          '<div class="me-3">' +
            '<span class="badge ' + levelClass + '">' + esc(level || "log") + "</span>" +
            kind +
          "</div>" +
          '<div class="text-muted small text-nowrap">' + esc(occurred) + "</div>" +
        "</div>" +
        '<div class="mt-2">' + esc(l.message ?? "") + "</div>" +
        where +
        linksHtml +
        stackHtml +
      "</div>"
    );
  }

  function renderLogs(logs) {
    if (!Array.isArray(logs) || logs.length === 0) {
      return '<div class="text-muted">No logs recorded for this host yet.</div>';
    }

    return '<div><h6 class="mb-2">Recent logs</h6><div class="list-group">' + logs.map(renderLogItem).join("") + "</div></div>";
  }

  function showModal(title, bodyHtml) {
    var titleEl = document.getElementById("kioskHostModalTitle");
    var bodyEl = document.getElementById("kioskHostModalBody");
    var modalEl = document.getElementById("kioskHostModal");
    if (!titleEl || !bodyEl || !modalEl) return;

    titleEl.textContent = title;
    bodyEl.innerHTML = bodyHtml;

    if (window.bootstrap && window.bootstrap.Modal) {
      window.bootstrap.Modal.getOrCreateInstance(modalEl).show();
      return;
    }
    if (window.jQuery && window.jQuery.fn && window.jQuery.fn.modal) {
      window.jQuery(modalEl).modal("show");
      return;
    }

    modalEl.classList.add("show");
    modalEl.style.display = "block";
  }

  function renderHostBody(data) {
    return renderHeartbeat(data.heartbeat || null) + renderLogs(Array.isArray(data.logs) ? data.logs : []);
  }

  document.addEventListener("click", async function (e) {
    var row = e.target.closest && e.target.closest(".kiosk-host-row[data-kiosk-host]");
    if (!row) return;

    var host = row.getAttribute("data-kiosk-host");
    if (!host) return;

    showModal(host, '<div class="text-muted">Loading...</div>');

    try {
      var data = await fetchHost(host);
      if (!data || data.ok !== true) throw new Error((data && data.error) || "not ok");
      showModal(host, renderHostBody(data));
    } catch (err) {
      showModal(host, '<div class="text-danger">Failed to load host details: ' + esc(err && err.message ? err.message : err) + '</div>');
    }
  });

  function setInputValue(form, name, val) {
    var input = form.querySelector('[name="' + name + '"]');
    if (!input) {
      input = document.createElement("input");
      input.type = "hidden";
      input.name = name;
      form.appendChild(input);
    }
    input.value = val;
  }

  function ensureHidden(form, name) {
    var input = form.querySelector('input[type="hidden"][name="' + name + '"]');
    if (!input) {
      input = document.createElement("input");
      input.type = "hidden";
      input.name = name;
      form.appendChild(input);
    }
    return input;
  }

  window.applyPresetRange = function (select) {
    var form = document.getElementById("filtersForm");
    var custom = document.getElementById("customDates");
    if (!form || !custom) return;

    var split = (select.value || "").split(":", 2);
    var key = split[0];
    var pair = split[1];
    ensureHidden(form, "preset_range").value = key;

    if (key === "custom") {
      custom.style.display = "";
      return;
    }

    custom.style.display = "none";
    var dates = (pair || "").split("|");
    setInputValue(form, "start", dates[0]);
    setInputValue(form, "end", dates[1]);
    form.requestSubmit();
  };

  function syncCustomDatesVisibility() {
    var select = document.getElementById("presetRange");
    if (!select) return;
    var key = (select.value || "").split(":", 1)[0];
    var custom = document.getElementById("customDates");
    if (custom) custom.style.display = (key === "custom") ? "" : "none";
    var form = document.getElementById("filtersForm");
    if (form) ensureHidden(form, "preset_range").value = key;
  }

  function initKioskUsageCharts() {
    if (!window.Chart) return;

    document.querySelectorAll("canvas[data-kiosk-usage-chart]").forEach(function (canvas) {
      var labels = JSON.parse(canvas.dataset.chartLabels || "[]");
      var data = JSON.parse(canvas.dataset.chartData || "[]");
      if (canvas.chartInstance) canvas.chartInstance.destroy();
      canvas.chartInstance = new Chart(canvas, {
        type: "line",
        data: {
          labels: labels,
          datasets: [{
            label: "Sessions",
            data: data,
            fill: false,
            borderColor: "rgb(54, 162, 235)",
            tension: 0.15,
            pointRadius: 2
          }]
        },
        options: {
          responsive: true,
          plugins: { legend: { display: false } },
          scales: {
            y: { beginAtZero: true, ticks: { precision: 0 } }
          }
        }
      });
    });
  }

  document.addEventListener("turbo:load", syncCustomDatesVisibility);
  document.addEventListener("DOMContentLoaded", syncCustomDatesVisibility);
  document.addEventListener("turbo:load", initKioskUsageCharts);
  document.addEventListener("DOMContentLoaded", initKioskUsageCharts);
})();
