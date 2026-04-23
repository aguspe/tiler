---
created: 2026-04-22T00:00:00Z
last_edited: 2026-04-22T00:00:00Z
---

# Cavekit: Widget Palette Drag-Drop

## Scope

Defines the drag-from-palette feature for the Tiler dashboard: a sidebar palette listing every registered widget that the user can drag onto the grid in edit mode. Covers the palette UI surface, the widget-registry contract for `default_config` / `default_size`, the drop flow that reuses the existing panel-create endpoint, cancel-mid-drag behavior, server-side widget_type validation, security/validation kit conformance, and end-to-end system test coverage.

This kit relies on `cavekit-dashboard-layout` R3 for layout coordinate validation and on `cavekit-widgets-smashing-parity` R7/R8/R9 for default-config conformance. It does not introduce new HTTP routes, new widget categories, or non-drag insertion paths.

## Requirements

### R1: Palette UI surface (sidebar)
**Description:** When the dashboard is in edit mode, a sidebar palette is visible on the left of the dashboard area, listing every registered widget type as a draggable tile. The palette is hidden when edit mode is off; toggling edit mode shows/hides the palette without page reload.
**Acceptance Criteria:**
- [ ] When `.tiler-editing` class is present on `.grid-stack` (edit mode on), an element with class `.tiler-widget-palette` is visible in the DOM and not display:none.
- [ ] When edit mode is off, the palette is `display: none` (no layout shift).
- [ ] The palette renders one element per registered widget type — query `Tiler.widgets` and emit one `[data-tiler-palette-widget][data-widget-type=<type>]` per registered widget.
- [ ] Each palette tile shows the widget label (from `klass.label`) and is draggable (either via `draggable="true"` or wired through gridstack's drag-in API).
- [ ] System test: with edit mode on, all registered widget types appear in the palette; toggling edit mode off hides them.
**Dependencies:** None.

### R2: Widget registry exposes default_config and default_size
**Description:** Each widget class declares a default config Hash (passed to `panel.config` JSON on drop) and a default size (`{w:, h:}` for the new tile). Built-in widgets override sensibly. Widgets that lack defaults inherit safe values.
**Acceptance Criteria:**
- [ ] `Tiler::Widget` base class exposes class-level `default_config` (returns `{}` by default) and `default_size` (returns `{w: 6, h: 2}` by default).
- [ ] Each built-in widget either inherits defaults or overrides:
  - `clock`, `text`, `iframe`, `image`, `comments`, `metric`, `number_with_delta`, `meter`, `list`, `table`, `pie_chart`, `bar_chart`, `line_chart`, `status_grid` — each must declare a default_config that is a valid Hash and renders without raising via `panel.data` and the partial.
  - `text` default includes a placeholder string (e.g., `{ "text" => "Edit me", "size" => "md" }`).
  - `image` default omits `url` so the partial renders the "No image URL configured" placeholder branch (no required-field error).
  - `meter` default omits `max` so the partial renders the "Configure max" placeholder (forces user to set a real max — closes the F-004 silent-blank-gauge concern from prior rounds).
  - `comments` default omits `quote_column` so the partial renders the "No comments yet." placeholder.
- [ ] Default configs MUST NOT contain values that violate `cavekit-widgets-smashing-parity` R7 (URL scheme allowlist) or R8 (enum whitelist). For example, no default `fit: "stretch"`, no default `aggregation: "sum_squared"`.
- [ ] Unit test parameterized over all registered widget types: for each type, a panel built from the widget's `default_config` and `default_size` calls `panel.data` without raising, and renders its partial without raising.
**Dependencies:** `cavekit-widgets-smashing-parity` R7, R8, R9.

### R3: Drop-on-grid creates a panel via existing endpoint
**Description:** Dropping a palette tile onto the grid POSTs to the existing panel-create endpoint with `widget_type`, default config, and the gridstack-computed coords. The new panel is added to the dashboard and rendered in the dropped slot. No new HTTP route is introduced.
**Acceptance Criteria:**
- [ ] On drop, JS handler reads the dragged tile's `data-widget-type`, computes `x/y/w/h` from gridstack's add-widget callback, and issues a POST to the existing dashboard-panel create endpoint with form params: `panel[widget_type]`, `panel[title]` (defaults to widget label), `panel[width]`, `panel[height]`, `panel[x]`, `panel[y]`, `panel[config]` (JSON-serialized default_config).
- [ ] On 2xx, the new panel turbo-frame is rendered into the dropped slot (Turbo Stream response or full-frame replace).
- [ ] On non-2xx, the dropped placeholder is removed and a flash error is surfaced.
- [ ] Server-side: panel is persisted with the supplied widget_type, coords, and config; persisted row passes existing model validations.
- [ ] Coords supplied by the drop are clamped/validated by the same rules as `cavekit-dashboard-layout` R3 (x in 0..11, y >= 0, w/h in 1..12).
**Dependencies:** R1, R2, `cavekit-dashboard-layout` R3.

### R4: Cancel-mid-drag
**Description:** A user can start dragging a palette tile and release outside the grid; this must not create a panel or leave a ghost element.
**Acceptance Criteria:**
- [ ] System test: drag a palette tile, release at a position outside `.grid-stack` bounds. After release, `Tiler::Panel.count` is unchanged and no `[data-tiler-palette-ghost]` (or equivalent placeholder) remains in the DOM.
- [ ] No POST is fired during the cancelled drag.
**Dependencies:** R1, R3.

### R5: Server rejects forged or unregistered widget_type
**Description:** A POST that arrives with a `widget_type` not present in the registry is rejected before persistence.
**Acceptance Criteria:**
- [ ] Controller test: POST to the panel-create endpoint with `widget_type: "../etc/passwd"` returns HTTP 422 (or equivalent unprocessable_entity) and creates no panel.
- [ ] Controller test: POST with `widget_type: ""` returns HTTP 422 and creates no panel.
- [ ] Controller test: POST with `widget_type: "image"` (a registered type) succeeds.
**Dependencies:** None.

### R6: Default configs respect existing security/validation kits
**Description:** Default configs supplied by R2 must never bypass the URL scheme allowlist (R7 of widgets-smashing-parity) or the enum whitelist (R8). Required-key error states (R9) must surface for any widget whose required config is intentionally omitted from defaults.
**Acceptance Criteria:**
- [ ] Unit test: `Tiler.widgets["image"].default_config["url"]` is either absent or in the allowed-scheme set; never starts with `javascript:`, `data:`, or `file:`.
- [ ] Unit test: `Tiler.widgets["meter"].default_config["aggregation"]` if present is in `%w[avg sum max min last]`; else absent (defaults to `last` per existing kit).
- [ ] Unit test: rendering a panel built from each widget's default config does not raise and does not produce a "valid-looking" misleading state — instead surfaces the configured-error placeholder where required keys are missing.
**Dependencies:** R2, `cavekit-widgets-smashing-parity` R7, R8, R9.

### R7: System tests for the drop flow
**Description:** End-to-end Capybara coverage for the palette drag-drop happy path and edge cases. Tests use the gridstack JS API for drop simulation (mirroring the existing pattern in `dashboard_flow_test.rb` for move/resize) since headless Chrome cannot pixel-drag reliably.
**Acceptance Criteria:**
- [ ] System test: in edit mode, drag a `clock` palette tile to slot `(0, 0)`; assert one Panel is persisted with `widget_type=clock`, x=0, y=0, default w/h.
- [ ] System test parameterized over every registered widget type: drop each onto a fresh dashboard, assert the panel renders without server error in its preview.
- [ ] System test: drop two palette tiles in quick succession; assert both panels persist with distinct ids and non-overlapping coords.
- [ ] System test: drop a palette tile, then drag the resulting panel to a new slot — assert PATCH layout fires and persists.
- [ ] System test: cancel drag (drop outside grid) — assert no panel created (covers R4).
**Dependencies:** R1, R2, R3, R4, R5.

## Out of Scope

- Custom widget previews/thumbnails in the palette beyond label text (icons, miniatures).
- Drag from palette directly to a different dashboard (cross-dashboard transfers).
- Drag-to-reorder within the palette itself.
- Keyboard-driven panel insertion (could add later under a separate a11y kit).
- Touch/mobile drag semantics beyond what gridstack provides natively.
- Inline-edit form auto-opening on drop — drop creates panel with default config and the user clicks Edit to refine.
- Bulk-add (drop many widgets at once).
- Saving/restoring custom palette layouts per user.
- Custom widget categories/grouping in the palette.

## Cross-References

- See also: [cavekit-dashboard-layout.md](./cavekit-dashboard-layout.md) — R3 layout PATCH validation applies to drop-supplied coords; R4 overflow smoke test should run with palette-created panels too.
- See also: [cavekit-widgets-smashing-parity.md](./cavekit-widgets-smashing-parity.md) — R7 URL allowlist + R8 enum whitelist + R9 required-key error states constrain default configs.
