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
      // float: true keeps the seeded layout intact on page load. Compact runs
      // after each user-initiated change instead — no permanent gaps when
      // panels are rearranged, but the initial layout you authored stays put.
      float: true,
      // Whole tile is the drag handle — drag works always (no edit mode toggle).
      handle: ".grid-stack-item-content",
      acceptWidgets: true,
      // Enable resize from every edge + corner (default is south-east only).
      // Hover near a side or corner to grow/shrink the tile.
      resizable: { handles: "n,e,s,w,ne,se,sw,nw" }
    }, this.gridTarget)

    // Responsive: under 720px, collapse to 1 column so tiles stack instead of
    // becoming pixel-thin. Re-applies on resize.
    this._applyResponsiveColumns()
    this._onResize = () => this._applyResponsiveColumns()
    window.addEventListener("resize", this._onResize)

    if (typeof window.GridStack.setupDragIn === "function") {
      window.GridStack.setupDragIn(".tiler-widget-palette-item", {
        appendTo: "body",
        helper: "clone"
      })
    }

    // Drag is always live. We do NOT add the .tiler-editing class globally —
    // that produced a 'whole dashboard is selected' visual. Drag affordance
    // lives in cursor + subtle outline-on-hover (CSS).
    this.paletteOpen = false
    // Persist on every change (move OR resize). We deliberately do NOT call
    // grid.compact() here: compacting on resize-change rebuilds sibling tiles'
    // resize handles in a way that intermittently broke their bindings (the
    // user could resize one tile, then a second tile would silently ignore
    // resize attempts). Compact only runs after `dragstop` (move freed a row)
    // or after a palette drop / panel delete (handleDrop).
    this._onChange   = (_event, items) => this.persistLayout(items)
    this._onDragStop = () => {
      if (typeof this.grid.compact === "function") this.grid.compact()
    }
    this._onDropped  = (_event, _previousNode, newNode) => this.handleDrop(newNode)
    this.grid.on("change",   this._onChange)
    this.grid.on("dragstop", this._onDragStop)
    this.grid.on("dropped",  this._onDropped)

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
    if (this._onResize) {
      window.removeEventListener("resize", this._onResize)
      this._onResize = null
    }
    if (this.grid) {
      try { this.grid.off("change", this._onChange) } catch (_e) { /* noop */ }
      try { this.grid.off("dropped", this._onDropped) } catch (_e) { /* noop */ }
    }
  }

  _applyResponsiveColumns() {
    if (!this.grid || typeof this.grid.column !== "function") return
    const targetCols = window.innerWidth <= 720 ? 1 : 12
    if (this._appliedColumns === targetCols) return
    this._appliedColumns = targetCols
    // 'list' layout stacks each tile full-width when the column count drops.
    try { this.grid.column(targetCols, "list") } catch (_e) {
      try { this.grid.column(targetCols) } catch (_e2) { /* noop */ }
    }
  }

  // Captures which palette item the user grabbed. Gridstack v10's setupDragIn
  // creates a fresh tile on drop — `newNode.el` does NOT carry our data-*
  // attrs. So we capture the source on dragstart and read it back in handleDrop.
  paletteDragStart(event) {
    const src = event.currentTarget
    if (!src) return
    this._draggedWidget = {
      widgetType: src.getAttribute("data-widget-type"),
      title: (src.querySelector(".tiler-widget-palette-label")?.textContent || src.getAttribute("data-widget-type") || "").trim(),
      defaultConfig: src.getAttribute("data-default-config") || "{}",
      defaultW: parseInt(src.getAttribute("data-default-w"), 10) || 6,
      defaultH: parseInt(src.getAttribute("data-default-h"), 10) || 2
    }
  }

  paletteDragEnd() {
    // Cleared on dragend regardless of whether drop succeeded — handleDrop
    // already consumed the value if the drop landed on the grid.
    this._draggedWidget = null
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
    // Prefer the captured palette source (set by paletteDragStart) — gridstack
    // v10's setupDragIn creates a fresh tile on drop that doesn't carry our
    // data-* attrs. Fall back to reading attrs off the new tile in case a
    // different drag-source pattern is used.
    const dragged = this._draggedWidget
    const widgetType = dragged?.widgetType || newNode.el.getAttribute("data-widget-type")
    if (!widgetType) {
      // Not a palette drop (likely an existing-panel move from another grid).
      return
    }
    const defaultConfig = dragged?.defaultConfig || newNode.el.getAttribute("data-default-config") || "{}"
    const title = dragged?.title || newNode.el.querySelector(".tiler-widget-palette-label")?.textContent.trim() || widgetType

    // Find any existing panels whose footprint overlaps the drop coords.
    // Drop-over-existing semantics: replace the underlying panel(s).
    const replacedIds = this._panelsOverlapping(newNode.el, newNode)

    // Remove the gridstack placeholder — the turbo_stream response appends
    // the real tile bound to the persisted panel record.
    this.grid.removeWidget(newNode.el, false, false)
    this._draggedWidget = null

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
