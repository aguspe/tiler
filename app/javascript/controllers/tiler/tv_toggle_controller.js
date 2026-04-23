import { Controller } from "@hotwired/stimulus"

// Per-dashboard TV-mode toggle on the Settings page. Calls the JSON API
// to persist the change so wall-mounted displays don't need a browser
// trip to the same machine.
export default class extends Controller {
  static values = { url: String, csrf: String }

  change(event) {
    const checked = event.currentTarget.checked
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfValue,
        "Accept": "application/json"
      },
      body: JSON.stringify({ settings: { tv_mode: checked } }),
      credentials: "same-origin"
    }).then((res) => {
      if (!res.ok) {
        // eslint-disable-next-line no-console
        console.warn("Tiler: TV-mode update failed", res.status)
        event.currentTarget.checked = !checked
      }
    })
  }
}
