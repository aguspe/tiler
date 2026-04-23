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
      staticGrid: false,
      float: true,
      // Whole tile is the drag handle — drag works always (no edit mode toggle).
      handle: ".grid-stack-item-content",
      acceptWidgets: true
    }, this.gridTarget)

    if (typeof window.GridStack.setupDragIn === "function") {
      window.GridStack.setupDragIn(".tiler-widget-palette-item", {
        appendTo: "body",
        helper: "clone"
      })
    }

    // Always-editable: panels carry the editing visual cue from the start.
    this.gridTarget.classList.add("tiler-editing")
    this.paletteOpen = false
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

  // Toggle the widget palette open/closed. Replaces the prior Edit Layout
  // toggle — drag-and-drop is always live; the only thing the button gates
  // is showing the palette of widget types you can drop onto the grid.
  togglePalette(event) {
    if (event && typeof event.preventDefault === "function") event.preventDefault()
    this.paletteOpen = !this.paletteOpen
    if (this.hasShellTarget) {
      this.shellTarget.classList.toggle("tiler-editing-mode", this.paletteOpen)
    }
    if (this.hasToggleTarget) {
      this.toggleTarget.textContent = this.paletteOpen ? "Close Palette" : "Add Panel"
      this.toggleTarget.setAttribute("aria-expanded", this.paletteOpen ? "true" : "false")
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

    // Find any existing panels whose footprint overlaps the drop coords.
    // Drop-over-existing semantics: replace the underlying panel(s).
    const replacedIds = this._panelsOverlapping(src, newNode)

    // Remove the gridstack placeholder — the turbo_stream response appends
    // the real tile bound to the persisted panel record.
    this.grid.removeWidget(src, false, false)

    // Delete any panels we're replacing, then create the new one.
    Promise.all(replacedIds.map((id) => this._deletePanel(id)))
      .then(() => this._createPanel({ widgetType, title, defaultConfig, node: newNode }))
      .catch((err) => {
        // eslint-disable-next-line no-console
        console.warn("Tiler: replace-on-drop error", err)
      })
  }

  // Return ids of existing panels whose grid coords overlap the dropped node.
  // Excludes the dropped placeholder itself.
  _panelsOverlapping(droppedEl, newNode) {
    const x1 = newNode.x, y1 = newNode.y
    const x2 = newNode.x + newNode.w, y2 = newNode.y + newNode.h
    const ids = []
    this.gridTarget.querySelectorAll(".grid-stack-item[gs-id]").forEach((item) => {
      if (item === droppedEl) return
      const ix = parseInt(item.getAttribute("gs-x"), 10)
      const iy = parseInt(item.getAttribute("gs-y"), 10)
      const iw = parseInt(item.getAttribute("gs-w"), 10)
      const ih = parseInt(item.getAttribute("gs-h"), 10)
      if (Number.isNaN(ix) || Number.isNaN(iy) || Number.isNaN(iw) || Number.isNaN(ih)) return
      const overlaps = ix < x2 && ix + iw > x1 && iy < y2 && iy + ih > y1
      if (!overlaps) return
      const id = item.getAttribute("gs-id")
      if (id) ids.push(id)
    })
    return ids
  }

  _deletePanel(id) {
    const url = this._panelDeleteUrl(id)
    if (!url) return Promise.resolve()
    return fetch(url, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": this.csrfValue,
        "Accept": "text/vnd.turbo-stream.html"
      },
      credentials: "same-origin"
    }).then((res) => {
      if (!res.ok) return
      // Remove the displaced tile from gridstack + DOM.
      const el = this.gridTarget.querySelector(`.grid-stack-item[gs-id='${id}']`)
      if (el) this.grid.removeWidget(el, true, false)
    })
  }

  _panelDeleteUrl(id) {
    const base = this.panelsUrlValue
    if (!base) return null
    return `${base}/${id}`
  }

  _createPanel({ widgetType, title, defaultConfig, node }) {
    const url = this.panelsUrlValue
    if (!url) return Promise.resolve()
    const fd = new FormData()
    fd.append("panel[widget_type]", widgetType)
    fd.append("panel[title]", title)
    fd.append("panel[x]", node.x)
    fd.append("panel[y]", node.y)
    fd.append("panel[width]", node.w)
    fd.append("panel[height]", node.h)
    fd.append("panel[config]", defaultConfig)
    return fetch(url, {
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
    })
  }
}
