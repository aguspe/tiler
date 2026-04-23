import { Controller } from "@hotwired/stimulus"

// Slide-over drawer that hosts a turbo-frame for inline panel editing.
// Wire-up:
//   <div data-controller="tiler--drawer"
//        data-tiler--drawer-frame-id-value="tiler_panel_edit_drawer">
//     <div data-tiler--drawer-target="backdrop" class="tiler-drawer-backdrop"
//          data-action="click->tiler--drawer#close"></div>
//     <aside data-tiler--drawer-target="panel" class="tiler-drawer">
//       <turbo-frame id="tiler_panel_edit_drawer"></turbo-frame>
//     </aside>
//   </div>
//
// Edit links opt into the drawer via data-turbo-frame="tiler_panel_edit_drawer".
// When that frame loads content, this controller toggles `.is-open`.
export default class extends Controller {
  static values  = { frameId: { type: String, default: "tiler_panel_edit_drawer" } }
  static targets = [ "panel", "backdrop" ]

  connect() {
    this._onFrameLoad = (e) => {
      if (e.target && e.target.id === this.frameIdValue) this.open()
    }
    this._onKey = (e) => { if (e.key === "Escape" && this._isOpen()) this.close() }
    document.addEventListener("turbo:frame-load", this._onFrameLoad)
    document.addEventListener("keydown", this._onKey)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this._onFrameLoad)
    document.removeEventListener("keydown", this._onKey)
  }

  // Trigger an edit-drawer load from any element with a Stimulus
  // `data-tiler--drawer-url-param="<panel edit url>"` value. We set the
  // turbo-frame `src` — Turbo fetches it and our turbo:frame-load listener
  // (see `connect`) opens the drawer once the response is in.
  openWith(event) {
    if (event && event.type === "keydown" && event.key !== "Enter") return
    event && event.preventDefault()
    const url = event?.params?.url ||
                event?.currentTarget?.getAttribute("data-tiler--drawer-url-param")
    if (!url) return
    const frame = document.getElementById(this.frameIdValue)
    if (!frame) return
    frame.setAttribute("src", url)
  }

  open() {
    this.panelTarget.classList.add("is-open")
    this.backdropTarget.classList.add("is-open")
    document.body.classList.add("tiler-drawer-open")
  }

  close(event) {
    event && event.preventDefault()
    this.panelTarget.classList.remove("is-open")
    this.backdropTarget.classList.remove("is-open")
    document.body.classList.remove("tiler-drawer-open")
    const frame = document.getElementById(this.frameIdValue)
    if (frame) {
      frame.removeAttribute("src")
      frame.innerHTML = ""
    }
  }

  _isOpen() { return this.panelTarget.classList.contains("is-open") }
}
