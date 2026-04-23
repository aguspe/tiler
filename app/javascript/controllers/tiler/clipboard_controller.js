import { Controller } from "@hotwired/stimulus"

// Copy-to-clipboard button. Pairs with a sibling/preceding element via a
// `target-selector` value or directly via a `text` value.
//
// <div data-controller="tiler--clipboard"
//      data-tiler--clipboard-text-value="paste me">
//   <code>paste me</code>
//   <button data-action="click->tiler--clipboard#copy">Copy</button>
// </div>
export default class extends Controller {
  static values = { text: String, label: { type: String, default: "Copy" }, doneLabel: { type: String, default: "Copied!" } }

  copy(event) {
    event && event.preventDefault()
    const text = this.textValue
    if (!text) return
    const btn = event.currentTarget
    const original = btn.textContent
    const restore = () => { btn.textContent = original; btn.classList.remove("tiler-btn-success") }
    const reportOk = () => {
      btn.textContent = this.doneLabelValue
      btn.classList.add("tiler-btn-success")
      setTimeout(restore, 1500)
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(reportOk).catch(() => this._fallback(text, reportOk))
    } else {
      this._fallback(text, reportOk)
    }
  }

  _fallback(text, ok) {
    const ta = document.createElement("textarea")
    ta.value = text
    ta.style.position = "fixed"
    ta.style.left = "-9999px"
    document.body.appendChild(ta)
    ta.select()
    try { document.execCommand("copy"); ok() } catch (_e) {}
    ta.remove()
  }
}
