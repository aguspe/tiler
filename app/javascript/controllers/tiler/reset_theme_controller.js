import { Controller } from "@hotwired/stimulus"

// Per-dashboard "Reset theme" button. PATCHes the four theme keys back to
// null in one round-trip so the dashboard falls back to the design-system
// defaults. Reloads the settings page so the color pickers re-render with
// the defaults instead of the user's previous values.
export default class extends Controller {
  static values = { url: String, csrf: String }

  reset(event) {
    event && event.preventDefault()
    const body = {
      settings: {
        page_bg: null, tile_bg: null, tile_header_bg: null, gutter_bg: null
      }
    }
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
      if (res.ok) window.location.reload()
    })
  }
}
