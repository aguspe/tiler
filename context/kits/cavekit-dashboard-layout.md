---
created: 2026-04-22T00:00:00Z
last_edited: 2026-04-22T00:00:00Z
---

# Cavekit: Dashboard Layout

## Scope

Codifies layout/CSS/test-infra contracts for the Tiler dashboard grid that prevent the panel-overflow, validation, and test-environment regressions surfaced in `/ck:check` rounds 2-3. Covers panel chrome sizing inside gridstack tiles, an opt-in scroll allowlist, layout PATCH input validation, a regression smoke test, dummy-app migration handling, and a turbo-frame eager-load mode for system tests.

This kit does NOT define new widgets, new endpoints, or new dashboard features — it locks down the contracts that existing dashboard rendering and persistence must satisfy.

## Requirements

### R1: Panel chrome sizing contract
**Description:** Inside a gridstack tile, the panel body sizes to the tile minus the header. Content that fits is shown flush with the bottom border; content that overflows is clipped (per opt-in scroll policy in R2). Standalone panel rendering (not inside `.tiler-grid-stack`) may have its own minimum height; the grid context must not.
**Acceptance Criteria:**
- [ ] CSS rule scoped to `.tiler-grid-stack .tiler-panel-body` sets `flex: 1 1 auto`, `overflow: hidden`, `min-height: 0`, finite padding.
- [ ] No CSS rule sets `min-height: 180px` (or any positive `min-height`) on `.tiler-panel-body` outside an explicit standalone-only scope. Removing or commenting out the grid-scoped rule must cause the regression test in R4 to fail.
- [ ] Panel header height is reserved before the body fills remaining space (`.tiler-grid-stack .tiler-panel` is `display: flex; flex-direction: column;`).
- [ ] Tile right + bottom borders are visible — body padding does not cover them.
**Dependencies:** None.

### R2: Opt-in scroll allowlist
**Description:** Most widgets clip when content overflows; content-heavy widgets opt into scrolling inside the panel body without disturbing the panel's bottom border.
**Acceptance Criteria:**
- [ ] Widgets that opt into scroll: `list`, `table`, `status_grid`, `text`. (Adding the `text` widget closes finding F-003 — multi-paragraph text panels must be readable.)
- [ ] Widgets that clip (no scroll): `clock`, `metric`, `number_with_delta`, `meter`, `image`, `comments`, `iframe`, `line_chart`, `bar_chart`, `pie_chart`.
- [ ] CSS opt-in is expressed as one rule per widget content class (e.g., `.tiler-grid-stack .tiler-list { max-height: 100%; overflow: auto; }`), not via inline JS or per-partial style.
- [ ] System test asserts `getComputedStyle(...).overflow` returns `auto`/`scroll` for the allowlisted widget classes and `hidden` for the others when each is rendered inside a tile.
**Dependencies:** R1 (the body must clip by default for opt-in to be meaningful).

### R3: Layout PATCH input validation
**Description:** The PATCH endpoint that persists drag-drop layout changes must enforce the same coordinate invariants as the model: `x` in `0..11`, `y >= 0`, `width` in `1..12`, `height` in `1..12`. Malformed payloads return a structured error.
**Acceptance Criteria:**
- [ ] PATCH with `x = -100` is rejected or clamped to `0`; the saved row never carries `x < 0` or `x > 11`.
- [ ] PATCH with `y = -5` is rejected or clamped to `0`; the saved row never carries `y < 0`.
- [ ] PATCH with `width = 0` or `width = 50` is clamped to `1..12` (existing behavior — codify it).
- [ ] PATCH with non-array `items` (e.g., `items: {}` or `items: "foo"`) returns 400 with a JSON error body, NOT 200 with no effect.
- [ ] PATCH with `items` containing entries lacking `id`/`x`/`y`/`w`/`h` keys is silently skipped per item; the response body indicates how many were applied vs skipped.
- [ ] Controller test covers each branch above.
**Dependencies:** None.

### R4: No-widget-overflow regression smoke test
**Description:** A system test that would catch the panel-overflow regression class (the bug behind commits 57cc836 / 0216a27) by asserting that no panel's rendered content overflows its tile, except for widgets in the R2 scroll allowlist.
**Acceptance Criteria:**
- [ ] System test seeds one panel of every registered widget type at a tight tile size (e.g., `w=3, h=2`) on a single dashboard.
- [ ] After turbo-frames render, the test reads `document.querySelectorAll('.grid-stack-item-content')` and for each non-allowlisted child asserts `child.scrollHeight <= child.clientHeight + 1` (the +1 accounts for sub-pixel rounding).
- [ ] Test fails if a non-allowlisted widget overflows; passes if all clip-or-fit.
- [ ] Reverting the grid-scoped CSS rule from R1 (or re-adding `min-height: 180px`) causes this test to fail.
**Dependencies:** R1, R2, R6 (eager-load avoids turbo-frame races during the assertion).

### R5: Test-infra — dummy app rebuilds from engine migrations
**Description:** The dummy app under `test/dummy` must be able to run `db:reset` end-to-end without manual `schema_migrations` stamping. Either (a) the dummy app's migrate path includes the engine's migrations, or (b) engine migrations are mirrored into `test/dummy/db/migrate/`.
**Acceptance Criteria:**
- [ ] Running `bin/rails db:drop db:create db:migrate` from `test/dummy` succeeds with exit code 0.
- [ ] After `db:migrate`, `Tiler.widgets.types` is enumerable and `Tiler::Dashboard.create!(name: "X")` succeeds (proves all engine tables exist).
- [ ] `bundle exec rails test` from the engine root succeeds without any pre-test SQL stamping or environment manipulation.
- [ ] CI workflow file (`.github/workflows/ci.yml`) does not contain manual `INSERT INTO schema_migrations` or equivalent workarounds.
**Dependencies:** None.

### R6: Turbo-frame eager-load test mode
**Description:** In `Rails.env.test?`, dashboard turbo-frames load eagerly (not lazily) so headless Chrome system tests don't race intersection-observer behavior. The change must not affect dev/production behavior.
**Acceptance Criteria:**
- [ ] A configuration flag `Tiler.configuration.eager_panel_load` (default `false`) controls the `loading:` attribute on dashboard turbo-frames.
- [ ] Test environment sets the flag to `true` (via initializer in `test/dummy/config/environments/test.rb` or equivalent).
- [ ] Existing system tests that use `5.times { reload }` workarounds either drop the workaround or the workaround becomes a no-op (they still pass).
- [ ] At least two system tests are simplified by removing the `5.times reload` pattern as part of meeting this requirement.
**Dependencies:** None.

## Out of Scope

- Generic gridstack feature additions (alignment guides, snapping rules) beyond what existing config provides.
- Theming/dark-mode CSS work.
- Mobile-responsive layout (gridstack already provides; not changing).
- Per-widget custom CSS that goes beyond the opt-in scroll rule.
- Replacing gridstack with another grid library.
- Server-side rendering of widget previews (current Turbo-frame lazy-load remains the dev/prod pattern).

## Cross-References

- See also: [cavekit-widgets-smashing-parity.md](./cavekit-widgets-smashing-parity.md) — R6 rotation visibility, R9 required-key states.
- See also: [cavekit-widget-palette-drag-drop.md](./cavekit-widget-palette-drag-drop.md) — palette drops generate PATCH layout calls; R3 validation applies to drop-supplied coords.
