import { Controller } from "@hotwired/stimulus"

// Live-preview a user-defined Liquid widget. Posts the current template +
// sample JSON to the controller's preview endpoint and drops the rendered
// HTML into the output div.
export default class extends Controller {
  static values = { url: String, csrf: String }

  run(event) {
    event && event.preventDefault()
    const tpl    = document.querySelector("[data-tiler-user-widget-template]").value
    const sample = document.querySelector("[data-tiler-user-widget-sample]").value
    const out    = document.querySelector("[data-tiler-user-widget-preview-output]")
    out.innerHTML = "<p class='tiler-muted'>Rendering…</p>"
    const fd = new FormData()
    fd.append("template",    tpl)
    fd.append("sample_data", sample)
    fetch(this.urlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": this.csrfValue, "Accept": "text/plain" },
      body: fd,
      credentials: "same-origin"
    }).then((res) => res.text().then((html) => {
      if (res.ok) {
        out.innerHTML = html
      } else {
        out.innerHTML = `<pre class="tiler-form-errors">${html}</pre>`
      }
    }))
  }
}
