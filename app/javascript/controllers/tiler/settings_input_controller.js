import { Controller } from "@hotwired/stimulus"

// Generic per-dashboard setting input on the Settings page. PATCHes the
// settings JSON endpoint with a single key/value on change. Text + url
// inputs debounce; color + checkbox + select fire immediately.
//
//   <input type="color"
//          data-controller="tiler--settings-input"
//          data-tiler--settings-input-url-value="<%= settings_api_v1_dashboard_path(d.slug) %>"
//          data-tiler--settings-input-csrf-value="<%= form_authenticity_token %>"
//          data-tiler--settings-input-key-value="background_color"
//          data-action="input->tiler--settings-input#change">
//
// Posts: { settings: { background_color: "#abcdef" } }
// The /settings endpoint shallow-merges, so other keys are preserved.
export default class extends Controller {
  static values = {
    url:      String,
    csrf:     String,
    key:      String,
    debounce: { type: Number, default: 350 }
  }

  change(event) {
    const el = event.currentTarget
    let value
    if (el.type === "checkbox") {
      value = el.checked
    } else if (el.value === "" && el.type !== "color") {
      // Empty string clears the setting.
      value = null
    } else {
      value = el.value
    }

    if (this._timer) clearTimeout(this._timer)
    const fire = () => this._patch(value, el)
    // Color picker fires an `input` per pixel — debounce hard. Text/url
    // inputs also debounce. Selects/checkboxes fire a single change so
    // posting immediately is fine.
    if (el.type === "checkbox" || el.tagName === "SELECT") {
      fire()
    } else {
      this._timer = setTimeout(fire, this.debounceValue)
    }
  }

  _patch(value, el) {
    const body = { settings: {} }
    body.settings[this.keyValue] = value
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfValue,
        "Accept": "application/json"
      },
      body: JSON.stringify(body),
      credentials: "same-origin"
    }).then((res) => {
      if (!res.ok) {
        // eslint-disable-next-line no-console
        console.warn("Tiler: settings update failed", res.status)
        el.classList.add("tiler-input-error")
        return
      }
      el.classList.remove("tiler-input-error")
      el.classList.add("tiler-input-saved")
      setTimeout(() => el.classList.remove("tiler-input-saved"), 800)
    })
  }
}
