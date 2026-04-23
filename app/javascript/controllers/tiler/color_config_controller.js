import { Controller } from "@hotwired/stimulus"

// Per-widget color override row on the panel edit form. Reads the panel's
// JSON config out of the textarea, sets/removes the `color` or `palette`
// key, and writes the JSON back. The Rails form submission picks up the
// new JSON like any other config edit.
//
// Targets:
//   - color   — single color picker (writes config.color)
//   - palette — comma-separated text input (writes config.palette: [...])
export default class extends Controller {
  static targets = [ "color", "palette" ]

  applySingle(event) {
    this._mutate((cfg) => {
      const v = event.currentTarget.value
      if (v) cfg.color = v; else delete cfg.color
    })
  }

  applyPalette(event) {
    this._mutate((cfg) => {
      const raw = event.currentTarget.value
      const arr = raw.split(",")
                     .map((s) => s.trim())
                     .filter((s) => /^#[0-9a-f]{3,8}$/i.test(s))
      if (arr.length) cfg.palette = arr; else delete cfg.palette
    })
  }

  clear() {
    this._mutate((cfg) => {
      delete cfg.color
      delete cfg.palette
    })
    if (this.hasColorTarget)   this.colorTarget.value   = "#3b82f6"
    if (this.hasPaletteTarget) this.paletteTarget.value = ""
  }

  _mutate(fn) {
    const ta = this._configField()
    if (!ta) return
    let cfg = {}
    try { cfg = JSON.parse(ta.value || "{}") } catch (_e) { cfg = {} }
    fn(cfg)
    ta.value = JSON.stringify(cfg)
  }

  _configField() {
    return document.querySelector("textarea[name='panel[config]']")
  }
}
