import { Controller } from "@hotwired/stimulus"

// Per-dashboard settings: today only "show/hide About". Persists user
// preferences to localStorage so the choice survives reloads.
export default class extends Controller {
  static values = { storageKey: { type: String, default: "tiler.settings" } }

  connect() {
    const prefs = this._read()
    if (prefs.aboutHidden) this._setAbout(false)
    this._refreshLabels(prefs)
  }

  toggleAbout(event) {
    event && event.preventDefault()
    const prefs = this._read()
    prefs.aboutHidden = !prefs.aboutHidden
    this._write(prefs)
    this._setAbout(!prefs.aboutHidden)
    this._refreshLabels(prefs)
    this._closeMenu()
  }

  _setAbout(visible) {
    const about = document.querySelector("[data-tiler-about]")
    if (!about) return
    if (visible) {
      about.style.display = ""
      about.removeAttribute("hidden")
    } else {
      about.style.display = "none"
      about.setAttribute("hidden", "")
    }
  }

  _refreshLabels(prefs) {
    const toggle = this.element.querySelector("[data-tiler-about-toggle]")
    if (toggle) toggle.textContent = prefs.aboutHidden ? "Show About" : "Hide About"
  }

  _closeMenu() {
    if (this.element.tagName === "DETAILS") this.element.removeAttribute("open")
  }

  _read() {
    try {
      const raw = localStorage.getItem(this.storageKeyValue)
      return raw ? JSON.parse(raw) : {}
    } catch (_e) { return {} }
  }

  _write(prefs) {
    try { localStorage.setItem(this.storageKeyValue, JSON.stringify(prefs)) } catch (_e) {}
  }
}
