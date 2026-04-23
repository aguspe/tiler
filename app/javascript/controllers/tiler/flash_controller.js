import { Controller } from "@hotwired/stimulus"

// Auto-dismissing flash banner. Shipped with the Tiler engine so host apps
// inherit it without wiring anything. Honors a `timeout-value` data attr
// (milliseconds, default 5000); when the timer expires the element is
// removed from the DOM. The close button can dismiss earlier.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    this._scheduleDismiss()
  }

  disconnect() {
    if (this._timer) {
      clearTimeout(this._timer)
      this._timer = null
    }
  }

  // Stimulus calls this whenever the value changes — handy for tests that
  // shorten the timeout to avoid waiting 5 seconds.
  timeoutValueChanged() {
    if (this._timer) clearTimeout(this._timer)
    this._scheduleDismiss()
  }

  dismiss() {
    if (this._timer) {
      clearTimeout(this._timer)
      this._timer = null
    }
    this.element.remove()
  }

  _scheduleDismiss() {
    const ms = this.timeoutValue
    if (!ms || ms <= 0) return
    this._timer = setTimeout(() => this.dismiss(), ms)
  }
}
