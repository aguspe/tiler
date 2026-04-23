import { Controller } from "@hotwired/stimulus"

// Inline-edit a single text field by double-clicking it. Used on the
// dashboard <h1> to rename without leaving the page.
//
//   <h1 data-controller="tiler--inline-edit"
//       data-tiler--inline-edit-url-value="<%= api_v1_dashboard_path(@dashboard.slug) %>"
//       data-tiler--inline-edit-csrf-value="<%= form_authenticity_token %>"
//       data-tiler--inline-edit-field-value="name"
//       data-tiler--inline-edit-resource-value="dashboard"
//       data-action="dblclick->tiler--inline-edit#edit
//                    keydown->tiler--inline-edit#onKey
//                    blur->tiler--inline-edit#save"
//       title="Double-click to rename"
//       tabindex="0">Acme</h1>
//
// Saves via PATCH { dashboard: { name: "..." } }. Reverts on validation
// failure and surfaces the server message via a flash element.
export default class extends Controller {
  static values = {
    url:      String,
    csrf:     String,
    field:    { type: String, default: "name" },
    resource: { type: String, default: "dashboard" }
  }

  edit(event) {
    if (event && event.preventDefault) event.preventDefault()
    if (this._editing) return
    this._original = this.element.textContent.trim()
    this._editing = true
    this.element.setAttribute("contenteditable", "true")
    this.element.spellcheck = false
    this.element.focus()
    this._selectAll()
  }

  onKey(event) {
    if (!this._editing) return
    if (event.key === "Enter") {
      event.preventDefault()
      this.element.blur()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this._cancel()
    }
  }

  save() {
    if (!this._editing) return
    this._editing = false
    this.element.removeAttribute("contenteditable")
    const next = this.element.textContent.trim()
    if (next === this._original) return
    if (!next) { this._revert("Name cannot be empty"); return }

    const body = {}
    body[this.resourceValue] = {}
    body[this.resourceValue][this.fieldValue] = next

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
      if (res.ok) {
        document.title = next
        this._flash(`Renamed to "${next}"`, "notice")
        return
      }
      res.json().catch(() => ({})).then((data) => {
        const msg = (data.errors && data.errors.join(", ")) || `Rename failed (${res.status})`
        this._revert(msg)
      })
    }).catch(() => this._revert("Rename failed (network)"))
  }

  _cancel() {
    this._editing = false
    this.element.removeAttribute("contenteditable")
    this.element.textContent = this._original
    this.element.blur()
  }

  _revert(message) {
    this.element.textContent = this._original
    this._flash(message, "alert")
  }

  _selectAll() {
    const range = document.createRange()
    range.selectNodeContents(this.element)
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)
  }

  _flash(message, kind) {
    const el = document.createElement("div")
    el.className = `tiler-flash tiler-flash-${kind === "alert" ? "alert" : "notice"}`
    el.setAttribute("data-controller", "tiler--flash")
    el.setAttribute("data-tiler--flash-timeout-value", "4000")
    el.setAttribute("role", "status")
    el.innerHTML = `<span class="tiler-flash-message"></span><button type="button" class="tiler-flash-close" data-action="click->tiler--flash#dismiss" aria-label="Dismiss">×</button>`
    el.querySelector(".tiler-flash-message").textContent = message
    document.body.prepend(el)
  }
}
