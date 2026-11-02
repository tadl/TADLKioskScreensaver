import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "metric", "grid", "empty", "fallback", "refreshStatus", "kioskTemplate", "hostTemplate"]
  static values = { url: String, tab: String }

  connect() {
    this.connected = true
    this.showTab(this.tabValue, false)
    this.refreshTimer = window.setInterval(() => this.refresh(), 30_000)
  }

  disconnect() {
    this.connected = false
    window.clearInterval(this.refreshTimer)
    this.request?.abort()
  }

  select(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    this.showTab(event.currentTarget.dataset.tab)
  }

  navigate(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    const keys = { ArrowRight: (index + 1) % this.tabTargets.length,
      ArrowLeft: (index + this.tabTargets.length - 1) % this.tabTargets.length,
      Home: 0, End: this.tabTargets.length - 1, " ": index }
    if (!(event.key in keys)) return
    event.preventDefault()
    const tab = this.tabTargets[keys[event.key]]
    tab.focus()
    this.showTab(tab.dataset.tab)
  }

  showTab(name, updateURL = true) {
    const selected = name === "stats" ? "stats" : "status"
    this.tabTargets.forEach(tab => {
      const active = tab.dataset.tab === selected
      tab.setAttribute("aria-selected", String(active))
      tab.tabIndex = active ? 0 : -1
    })
    this.panelTargets.forEach(panel => { panel.hidden = panel.dataset.tab !== selected })
    if (updateURL) {
      const url = new URL(window.location.href)
      if (selected === "stats") url.searchParams.set("tab", "stats")
      else url.searchParams.delete("tab")
      window.history.replaceState(window.history.state, "", url)
    }
  }

  resume() { if (!document.hidden) this.refresh() }

  async refresh() {
    if (!this.connected || document.hidden || this.request) return
    const request = new AbortController()
    this.request = request
    const timeout = window.setTimeout(() => request.abort(), 15_000)
    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.search = window.location.search
      const response = await fetch(url, { headers: { Accept: "application/json" },
        credentials: "same-origin", cache: "no-store", signal: request.signal })
      if (!this.connected) return
      if (response.redirected || response.status === 401) {
        this.refreshStatusTarget.textContent = "Sign in again to resume live updates."
        window.clearInterval(this.refreshTimer)
        return
      }
      if (!response.ok) throw new Error("Status refresh failed")
      const snapshot = await response.json()
      if (this.connected) this.renderSnapshot(snapshot)
    } catch {
      if (this.connected) this.refreshStatusTarget.textContent = "Live updates unavailable. Retrying…"
    } finally {
      window.clearTimeout(timeout)
      this.request = null
    }
  }

  renderSnapshot(snapshot) {
    if (!Array.isArray(snapshot.kiosks) || !snapshot.metrics ||
        !Number.isFinite(Date.parse(snapshot.updated_at)) ||
        this.metricTargets.some(metric => !Number.isInteger(snapshot.metrics[metric.dataset.metric]))) {
      throw new Error("Invalid status response")
    }
    const cards = document.createDocumentFragment()
    const focusedId = this.gridTarget.contains(document.activeElement) ? document.activeElement.dataset.statusId : null
    snapshot.kiosks.forEach(kiosk => {
      const card = this.kioskTemplateTarget.content.firstElementChild.cloneNode(true)
      card.querySelector("[data-overview-kiosk-name]").textContent = kiosk.name
      card.querySelector("[data-overview-kiosk-group]").textContent = kiosk.group
      const hosts = card.querySelector("[data-overview-kiosk-hosts]")
      kiosk.hosts.forEach(host => {
        const row = this.hostTemplateTarget.content.firstElementChild.cloneNode(true)
        row.dataset.statusId = host.id
        row.href = host.url
        row.classList.add(host.state === "opac" ? "is-active" : "is-idle")
        row.title = `${host.host} · ${host.state === "opac" ? "In use" : "Screensaver"}`
        row.setAttribute("aria-label", `${row.title} · ${host.duration}`)
        row.querySelector("[data-overview-host-name]").textContent = host.host
        row.querySelector("[data-overview-host-duration]").textContent = host.duration
        hosts.append(row)
      })
      cards.append(card)
    })
    this.gridTarget.replaceChildren(cards)
    this.gridTarget.hidden = snapshot.kiosks.length === 0
    this.emptyTarget.hidden = snapshot.kiosks.length !== 0
    this.fallbackTarget.hidden = !snapshot.fallback_missing
    this.metricTargets.forEach(metric => { metric.textContent = snapshot.metrics[metric.dataset.metric] })
    if (focusedId) {
      this.gridTarget.querySelector(`[data-status-id="${CSS.escape(focusedId)}"]`)?.focus({ preventScroll: true })
    }
    const updated = new Date(snapshot.updated_at).toLocaleTimeString([], { hour: "numeric", minute: "2-digit", second: "2-digit" })
    this.refreshStatusTarget.textContent = `Updated ${updated} · Every 30s`
  }
}
