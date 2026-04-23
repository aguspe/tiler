import { Controller } from "@hotwired/stimulus"

// Confirmation modal that replaces the native browser confirm() dialog so
// destructive actions look like the rest of Tiler. Wire via:
//   <button data-controller="tiler--modal"
//           data-action="click->tiler--modal#open"
//           data-tiler--modal-message-value="Delete this panel?"
//           data-tiler--modal-confirm-label-value="Delete"
//           data-tiler--modal-action-value="/tiler/.../panels/123"
//           data-tiler--modal-method-value="delete">Delete</button>
//
// On confirm, builds + submits a hidden form so Rails handles the request
// (CSRF + _method intact) — no fetch dance, full-page redirect on success.
export default class extends Controller {
  static values = {
    message: { type: String, default: "Are you sure?" },
    confirmLabel: { type: String, default: "Confirm" },
    cancelLabel: { type: String, default: "Cancel" },
    action: String,
    method: { type: String, default: "delete" }
  }

  open(event) {
    event && event.preventDefault()
    if (this._modal) return
    const overlay = document.createElement("div")
    overlay.className = "tiler-modal-overlay"
    overlay.setAttribute("data-tiler-modal-overlay", "")
    overlay.innerHTML = `
      <div class="tiler-modal" role="dialog" aria-modal="true" aria-labelledby="tiler-modal-title">
        <p class="tiler-modal-title" id="tiler-modal-title">${this._escape(this.messageValue)}</p>
        <div class="tiler-modal-actions">
          <button type="button" class="tiler-btn" data-tiler-modal-cancel>${this._escape(this.cancelLabelValue)}</button>
          <button type="button" class="tiler-btn tiler-btn-danger" data-tiler-modal-confirm>${this._escape(this.confirmLabelValue)}</button>
        </div>
      </div>`
    document.body.appendChild(overlay)
    this._modal = overlay
    overlay.querySelector("[data-tiler-modal-cancel]").addEventListener("click", () => this.close())
    overlay.querySelector("[data-tiler-modal-confirm]").addEventListener("click", () => this.confirm())
    overlay.addEventListener("click", (e) => { if (e.target === overlay) this.close() })
    this._escapeKey = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this._escapeKey)
  }

  close() {
    if (!this._modal) return
    document.removeEventListener("keydown", this._escapeKey)
    this._modal.remove()
    this._modal = null
  }

  confirm() {
    if (!this.actionValue) { this.close(); return }
    const form = document.createElement("form")
    form.method = "post"
    form.action = this.actionValue
    const csrf = document.querySelector("meta[name='csrf-token']")?.content
    if (csrf) {
      const csrfInput = document.createElement("input")
      csrfInput.type = "hidden"
      csrfInput.name = "authenticity_token"
      csrfInput.value = csrf
      form.appendChild(csrfInput)
    }
    if (this.methodValue && this.methodValue.toLowerCase() !== "post") {
      const methodInput = document.createElement("input")
      methodInput.type = "hidden"
      methodInput.name = "_method"
      methodInput.value = this.methodValue
      form.appendChild(methodInput)
    }
    document.body.appendChild(form)
    form.submit()
  }

  _escape(str) {
    return String(str).replace(/[&<>"']/g, (c) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"
    }[c]))
  }
}
