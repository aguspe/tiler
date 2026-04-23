import { Controller } from "@hotwired/stimulus"

// Tiler dashboard grid — replaces the inline IIFE that used to live in
// app/views/tiler/dashboards/show.html.erb. Wraps GridStack init, edit-mode
// toggle, layout PATCH persistence, palette drag/drop, and refresh interval.
//
// Gridstack itself is loaded via a CDN script in the Tiler engine layout.
export default class extends Controller {
  static targets = ["toggle", "shell", "grid"]
  static values = {
    layoutUrl: String,
    panelsUrl: String,
    csrf: String,
    refreshSeconds: { type: Number, default: 0 },
    // When ActionCable is wired and host opts in to Turbo Streams broadcasts,
    // polling becomes redundant (and would fight Turbo morphs). Default off
    // so polling stays on by default — opt-in via Tiler.configuration.disable_polling.
    disablePolling: { type: Boolean, default: false }
  }

  connect() {
    // No grid target means an empty dashboard — nothing to wire up.
    if (!this.hasGridTarget) return

    if (!window.GridStack) {
      // Gridstack CDN not loaded yet — retry shortly. Cap retries so we
      // don't busy-loop if the CDN is unreachable.
      this._retries = (this._retries || 0) + 1
      if (this._retries > 50) return
      this._retryTimer = setTimeout(() => this.connect(), 100)
      return
    }

    this.grid = window.GridStack.init({
      column: 12,
      cellHeight: 90,
      margin: 0,
      staticGrid: true,
      float: true,
      handle: ".tiler-panel-header",
      acceptWidgets: true
    }, this.gridTarget)

    if (typeof window.GridStack.setupDragIn === "function") {
      window.GridStack.setupDragIn(".tiler-widget-palette-item", {
        appendTo: "body",
        helper: "clone"
      })
    }

    this.editing = false
    this._onChange = (_event, items) => this.persistLayout(items)
    this._onDropped = (_event, _previousNode, newNode) => this.handleDrop(newNode)
    this.grid.on("change", this._onChange)
    this.grid.on("dropped", this._onDropped)

    if (this.refreshSecondsValue > 0 && !this.disablePollingValue) {
      this.refreshInterval = setInterval(() => {
        this.gridTarget.querySelectorAll("turbo-frame").forEach((f) => {
          if (typeof f.reload === "function") f.reload()
        })
      }, this.refreshSecondsValue * 1000)
    }
  }

  disconnect() {
    if (this._retryTimer) {
      clearTimeout(this._retryTimer)
      this._retryTimer = null
    }
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
      this.refreshInterval = null
    }
    if (this.grid) {
      try { this.grid.off("change", this._onChange) } catch (_e) { /* noop */ }
      try { this.grid.off("dropped", this._onDropped) } catch (_e) { /* noop */ }
    }
  }

  toggle(event) {
    if (event && typeof event.preventDefault === "function") event.preventDefault()
    this.setEditing(!this.editing)
  }

  setEditing(on) {
    this.editing = on
    if (!this.grid) return
    this.grid.setStatic(!on)
    this.grid.enableMove(on)
    this.grid.enableResize(on)
    if (this.hasGridTarget) this.gridTarget.classList.toggle("tiler-editing", on)
    if (this.hasShellTarget) {
      this.shellTarget.classList.toggle("tiler-editing-mode", on)
    }
    if (this.hasToggleTarget) {
      this.toggleTarget.textContent = on ? "Done Editing" : "Edit Layout"
      this.toggleTarget.classList.toggle("tiler-btn-primary", on)
    }
  }

  persistLayout(items) {
    if (!this.layoutUrlValue) return
    const payload = {
      items: items.map((i) => ({
        id: i.el.getAttribute("gs-id"),
        x: i.x, y: i.y, w: i.w, h: i.h
      }))
    }
    fetch(this.layoutUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfValue,
        "Accept": "application/json"
      },
      body: JSON.stringify(payload),
      credentials: "same-origin"
    })
  }

  handleDrop(newNode) {
    if (!newNode || !newNode.el) return
    const src = newNode.el
    const widgetType = src.getAttribute("data-widget-type")
    if (!widgetType) {
      // Not a palette drop (likely an existing-panel move from another grid).
      return
    }
    const defaultConfig = src.getAttribute("data-default-config") || "{}"
    const labelEl = src.querySelector(".tiler-widget-palette-label")
    const title = labelEl ? labelEl.textContent.trim() : widgetType

    // Remove the placeholder gridstack created — the turbo_stream response
    // appends the real tile bound to the persisted panel record.
    this.grid.removeWidget(src, false, false)

    const fd = new FormData()
    fd.append("panel[widget_type]", widgetType)
    fd.append("panel[title]", title)
    fd.append("panel[x]", newNode.x)
    fd.append("panel[y]", newNode.y)
    fd.append("panel[width]", newNode.w)
    fd.append("panel[height]", newNode.h)
    fd.append("panel[config]", defaultConfig)

    const url = this.panelsUrlValue || (this.hasGridTarget ? this.gridTarget.dataset.tilerPanelsUrl : null)
    if (!url) return

    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfValue,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: fd,
      credentials: "same-origin"
    }).then((res) => {
      if (!res.ok) {
        // eslint-disable-next-line no-console
        console.warn("Tiler: panel create failed (" + res.status + ")")
        return
      }
      return res.text().then((html) => {
        if (window.Turbo && typeof window.Turbo.renderStreamMessage === "function") {
          window.Turbo.renderStreamMessage(html)
        }
        // After Turbo appends the new tile, ask gridstack to hydrate it so it
        // participates in subsequent move/resize events.
        setTimeout(() => {
          this.gridTarget.querySelectorAll(".grid-stack-item").forEach((item) => {
            if (!item.gridstackNode) this.grid.makeWidget(item)
          })
        }, 100)
      })
    }).catch((err) => {
      // eslint-disable-next-line no-console
      console.warn("Tiler: panel create error", err)
    })
  }
}
