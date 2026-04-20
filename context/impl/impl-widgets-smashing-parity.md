---
created: 2026-04-19
last_edited: 2026-04-19
Build site: context/plans/build-site.md
---

# Implementation Log: Widgets — Smashing Parity

## Tasks

### T-001: Image widget class + partial — DONE (2026-04-19)
- Created `/Users/augustingottlieb/tiler/lib/tiler/widgets/image.rb` (config-only widget; subclasses `Tiler::Widget`; `type="image"`, `label="Image"`, `partial="tiler/widgets/image"`, `query_class=nil`; `#data` returns `{url:, alt:, fit:}`; `fit` defaults to `"contain"` when blank/missing; `url`/`alt` coerced via `.to_s`).
- Created `/Users/augustingottlieb/tiler/app/views/tiler/widgets/_image.html.erb` mirroring iframe partial's empty-state pattern. Blank `data[:url]` -> `<p class="tiler-muted">No image URL configured.</p>` with zero `<img>` tags. Non-blank -> exactly one `<img class="tiler-image">` with `src=data[:url]`, `alt=data[:alt]`, `style="object-fit: <fit>; width: 100%; height: 100%;"`, `loading="lazy"`, `referrerpolicy="no-referrer"`.
- Self-registers via `Tiler.widgets.register("image", klass: Tiler::Widgets::Image)` (corrected from build-site's wrong `register(self)` signature).
- Smoke test confirms `Tiler.widgets["image"]` returns the class with the expected type/label/partial/query_class.
- Engine require (R4), seed entry (R4), panel-form dropdown verification (R1-AC8 / T-006), and dedicated test file (R5 / T-007) are scoped to other tasks.

### T-002: Meter widget class + nested query — DONE (2026-04-19)
- Created `/Users/augustingottlieb/tiler/lib/tiler/widgets/meter.rb` with sibling-class convention (`Tiler::Widgets::MeterQuery`) matching existing `metric.rb` / `number_with_delta.rb` pattern (build-site originally said nested `Meter::Query`; corrected to sibling `MeterQuery` to match existing code).
- `MeterQuery#call` returns exactly the five-key hash `{ value:, min:, max:, prefix:, suffix: }`; `:value` is clamped into `[min, max]` (or returns nil when raw is nil; passes through unchanged when max is nil).
- `:min` defaults to `0`; `:max` defaults to `nil`. Coerces config values via `Float()` with rescue.
- Aggregation defaults to `"last"`; relies on `Tiler::Query::Base#aggregate` (confirmed `last` returns most recent `recorded_at` value via `scope.order(recorded_at: :desc).limit(1).pluck(...).first`).
- Empty data source: `aggregate` returns `nil` for `last`/`avg`/`min`/`max`/`sum` on empty scope, `clamp(nil, ...)` returns `nil`, hash still has all five keys.
- Self-registers via `Tiler.widgets.register("meter", klass: Tiler::Widgets::Meter)` (corrected from build-site's wrong `register(self)` signature).
- Partial creation deferred to T-004; engine wiring to T-005; tests to T-008.

### T-003: Comments widget class + sibling query — DONE (2026-04-19)
- Created `/Users/augustingottlieb/tiler/lib/tiler/widgets/comments.rb` with sibling-class convention (`Tiler::Widgets::CommentsQuery`) matching existing `metric.rb` / `number_with_delta.rb` / `list.rb` / `meter.rb` pattern (build-site originally said nested `Comments::Query`; corrected to sibling `CommentsQuery` to match existing code).
- `CommentsQuery#call` returns `{ items:, rotate_seconds: }`. `:items` is an Array of hashes with exactly the keys `:quote, :name, :avatar` (R3-AC2, R3-AC3).
- Items ordered via `base_scope.order(recorded_at: :desc).limit(limit)`; `clamp_limit` defaults to `10`, lower-bounds at `1`, upper-caps at `MAX_LIMIT = 100` (R3-AC4).
- Missing `name_column` / `avatar_column` config keys → corresponding value is `nil` (guard via `present?`); missing payload key → `payload[col]` returns `nil` from the parsed hash. No raise (R3-AC5).
- `quote_col` blank or unsafe → returns `items: []` without scanning records; same shape preserved (R3-AC6, R3-AC8).
- `rotate_seconds` returns `config["rotate_seconds"].to_i` when positive, else `DEFAULT_ROTATE_SECONDS = 8` (R3-AC7).
- Defensive `parse_payload(record)` handles both Hash (future) and JSON String (current — `Tiler::DataRecord#payload` is a JSON text column; model exposes `parsed_payload`/`[]` but query iterates raw scope, so we parse here). `JSON::ParserError` → `{}`.
- Self-registers via `Tiler.widgets.register("comments", klass: Tiler::Widgets::Comments)` (corrected from build-site's wrong `register(self)` signature).
- Partial creation deferred to T-005; engine wiring to T-006-equivalent (R4); tests to T-009 (R5). R3-AC1/AC9/AC10/AC11/AC12 are partial/registry/dropdown concerns owned by other tasks.

### T-004: Meter partial (SVG gauge) — DONE (2026-04-19)
- Created `/Users/augustingottlieb/tiler/app/views/tiler/widgets/_meter.html.erb` consuming locals `panel:` and `data:` (the five-key hash from `MeterQuery`: `{value:, min:, max:, prefix:, suffix:}`).
- 3/4-circle Smashing-style gauge: `start_deg = -125.0`, `sweep_deg = 250.0`, center `(100,100)`, radius `80`, viewBox `0 0 200 200`. Two SVG `<path>` arcs: background (full sweep, gray `#e5e7eb`) and foreground (filled portion, blue `#3b82f6`, only emitted when `pct > 0`).
- Fill ratio: `pct = ((value - min) / (max - min)).clamp(0.0, 1.0)`. Foreground arc endpoint `(fg_end_x, fg_end_y)` is computed from `start_deg + sweep_deg * pct`, so `value == min` and `value == max` produce divergent SVG markup: at min, the foreground `<path>` element is omitted entirely (`pct == 0`); at max, the foreground path spans the full 250° sweep with `large-arc-flag = 1` (R2-AC9).
- Prefix/suffix adjacency (R2-AC8): rendered as `<%= data[:prefix] %><%= display_value %><%= data[:suffix] %>` inside one `<text>` node — zero intervening whitespace/characters in the ERB source. Nil prefix/suffix → ERB emits empty string, no extra markup.
- Nil-value tolerance (R2 nil tolerance): `has_value` guard requires `value` to be Numeric AND `max` to be a Numeric > min; when false, `pct = 0.0` (renders empty background-only gauge) and `display_value = "—"` (em dash placeholder). Covers both `data[:value] == nil` (empty data source) and `data[:max]` missing/non-numeric. No raise paths.
- Number formatting: `v.to_f.round(2).to_s.sub(/\.0+\z/, "")` strips trailing `.0` for integer-valued floats (e.g. `42.0` → `"42"`, `42.5` → `"42.5"`).
- R2-AC7 (SVG presence): exactly one `<svg>` element with `viewBox="0 0 200 200"`, `class="tiler-meter-svg"`, containing 1–2 `<path>` arcs and 1 `<text>` node.
- Constraints respected: did not touch `engine.rb`, `meter.rb`, tests, or seed. Did not commit.
- Test verification deferred to T-008 (will assert `<svg>` presence, prefix/suffix adjacency, min-vs-max divergence, nil-value non-raise).

### T-006: Engine registration + seed wiring — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/lib/tiler/engine.rb`: appended three `require` lines (`tiler/widgets/image`, `tiler/widgets/meter`, `tiler/widgets/comments`) at the bottom of the existing `tiler.register_builtin_widgets` initializer block, alongside the eleven pre-existing widget requires (R4-AC1).
- Edited `/Users/augustingottlieb/tiler/lib/tasks/tiler_tasks.rake`: appended three `dash.panels.create!` calls inside the `if dash.panels.empty?` block, after the eight pre-existing seeded panels (R4-AC3). Coordinates: image at `(x:0, y:8, w:4, h:3)`, meter at `(x:4, y:8, w:4, h:3, data_source: source)`, comments at `(x:8, y:8, w:4, h:3, data_source: source)` — three side-by-side slots on a fresh y=8 row, no overlap with pre-existing panels which fill y=0–2 (4 panels), y=2–5 (line_chart 8w + pie_chart 4w), y=5–8 (list 4w + iframe 8w). Collision detector confirmed `COLLISIONS=[]` across all 11 panels (R4-AC4).
- Configs respect dispatch spec exactly: image with `{url, alt, fit:"contain"}`; meter with `{value_column:"duration", aggregation:"avg", time_window:"24h", min:0, max:1000, suffix:" ms"}`; comments with `{quote_column:"status", time_window:"7d", limit:10, rotate_seconds:5}`. quote_column="status" is intentional — the demo source's payload only has `status` + `duration` keys, and `status` is the only string field.
- Smoke checks (development env, sqlite):
  1. `rails db:reset` → "Created database 'storage/development.sqlite3'", no errors.
  2. `rails tiler:seed` → "Tiler seeded. Visit /tiler/dashboards/demo".
  3. `Tiler.widgets.types.sort.join(",")` → `bar_chart,clock,comments,iframe,image,line_chart,list,meter,metric,number_with_delta,pie_chart,status_grid,table,text` — includes all three new types (R4-AC2 satisfied).
  4. Demo dashboard panel count = 11 (8 pre-existing + 3 new); `widget_type` distinct values include `image`, `meter`, `comments` (R4-AC3 satisfied).
  5. Direct partial render via FakeCtrl for each new seeded panel returned non-zero bytes with no exception: image=395 bytes (`<img class="tiler-image">`), meter=726 bytes (`<svg viewBox="0 0 200 200" class="tiler-meter">`), comments=1978 bytes (`<div id="tiler-comments-11" class="tiler-comments">`) (R4-AC6 satisfied — the same partial rendering path the dashboard `show` view uses works without raising for all three new widgets backed by their seeded configs).
  6. Full-page rack-test fetch returned 403 due to host authorization middleware in dev env, not a controller/view exception; bypassing via direct partial render (above) confirms the render path itself is exception-free.
- No new migration files added (R4-AC5 satisfied — `git status` shows the only untracked migration is `20260419020000_add_grid_layout_to_tiler_panels.rb` which pre-dated T-006 per initial gitStatus snapshot; T-006 added zero migrations because image/meter/comments configs all live in the existing `tiler_panels.config` JSON column).
- R1-AC8 / R2-AC10 / R3-AC12 (panel-form dropdown visibility) follow automatically from R4-AC2 because the form is populated from `Tiler.widgets.all`; explicit dropdown verification not exercised here but is now possible.
- Constraints respected: edited only `engine.rb` and `tiler_tasks.rake`. Did not touch widget classes, partials, tests. Did not commit (per dispatch instructions).

### T-005: Comments partial + client-side rotator — DONE (2026-04-19)
- Created `/Users/augustingottlieb/tiler/app/views/tiler/widgets/_comments.html.erb` following the existing Tiler vanilla-ERB + inline `<script>` IIFE convention (NOT Stimulus — engine has no `app/javascript/` and no Stimulus controllers; build-site's Stimulus assumption was overridden per dispatch instructions).
- Locals: `panel:`, `data:` (`{ items:, rotate_seconds: }` from T-003's CommentsQuery).
- Empty `data[:items]` → renders `<p class="tiler-muted">No comments yet.</p>` (mirrors iframe/list empty-state pattern).
- Non-empty → root `<div id="tiler-comments-<%= panel.id %>" class="tiler-comments" data-tiler-rotate-interval="<%= data[:rotate_seconds] %>">`; unique container id keeps multiple comments panels on one dashboard from colliding (R3-AC9 satisfied — root data attribute equals `rotate_seconds`).
- Every item rendered into DOM inside `<div class="tiler-comment">` (first one also `tiler-comment-active`); rotation is purely client-side cycling over already-loaded markup (R3-AC10 satisfied — every quote text appears in output).
- Per-item: always renders `<blockquote class="tiler-comment-quote">` with the quote; `item[:name].present?` guards the `<p class="tiler-comment-name">` node; `item[:avatar].present?` guards the `<img class="tiler-comment-avatar">` (R3-AC11 satisfied — missing name/avatar branches do not raise; avatar `<img>` only emitted when present).
- Inline vanilla `<script>` IIFE: `document.getElementById(container_id)`, selects `.tiler-comment` nodes, early-returns on `<= 1` items, reads interval from the data attribute with `parseInt(..., 10) || 8` fallback, `setInterval` toggles `tiler-comment-active` every `interval * 1000` ms. No Stimulus controller, no `app/javascript/` directory.
- CSS for `.tiler-comment-active` visibility is out of scope per kit's "Out of Scope" section; acceptance criteria are DOM-presence + data-attribute based, both satisfied.
- No other files touched (engine.rb, comments.rb, tests, seed, stylesheet) per task constraints. Did not commit. Engine require/registration deferred to T-006; tests to T-009.

### T-007: Image widget tests — DONE (2026-04-19)
- Created `/Users/augustingottlieb/tiler/test/lib/tiler/widgets/image_test.rb` (created the new `test/lib/tiler/widgets/` directory; previously only `configuration_test.rb`, `query_test.rb`, `widget_registry_test.rb` lived under `test/lib/tiler/`).
- `ActionView::TestCase` subclass so `render partial:` is available; `setup do @dash = create_dashboard end` mirrors `query_test.rb` style. Helpers: `panel_with(config)` builds a `widget_type: "image"` panel via `create_panel` with JSON-encoded config; `render_partial(panel)` renders `tiler/widgets/image` with locals `panel:` and `data: panel.data`.
- Nine tests, 26 assertions, all green:
  1. Registry attributes: `Tiler.widgets["image"] == Tiler::Widgets::Image`; `type=="image"`, `label=="Image"`, `partial=="tiler/widgets/image"`, `query_class.nil?` (R1-AC1, R5-AC2).
  2. `#data` typical config returns `{url:, alt:, fit:}` matching supplied values (R1-AC2).
  3. `#data[:fit]` defaults to `"contain"` when omitted (R1-AC3).
  4. `#data[:fit]` defaults to `"contain"` when blank string `""` (R1-AC3).
  5. Partial with valid url renders exactly one `<img` tag (`html.scan(/<img\b/).size == 1`); includes `src="https://example.com/x.png"`, `alt="X"`, and `object-fit: cover` style cue (R1-AC4, R1-AC5, R1-AC7, R5-AC4).
  6. Partial with `alt` omitted still renders `alt=""` (R1-AC7).
  7. Partial with blank url renders zero `<img` tags and a `tiler-muted` placeholder element (R1-AC6).
  8. Partial with no `url` key at all does not raise and renders zero `<img` tags (R1-AC6 robustness).
  9. Registry enumeration: `Tiler.widgets.types` includes `"image"`, and `options_for_select` contains the `["Image", "image"]` pair so the panel-form dropdown surfaces the widget (R1-AC8).
- Note on test instructions vs. actual API: build-site/dispatch said `Tiler.widgets.lookup("image")` and `Tiler.widgets.all`, but `Tiler::WidgetRegistry` exposes `[]`, `fetch`, `types`, `each`, and `options_for_select` (no `lookup`/`all`). Test uses `[]` (matches existing `widget_registry_test.rb` style) and `types` + `options_for_select` for enumeration coverage.
- Run results from `/Users/augustingottlieb/tiler` root via `bundle exec rails test test/lib/tiler/widgets/image_test.rb`: `9 runs, 26 assertions, 0 failures, 0 errors, 0 skips`. Full-suite `bundle exec rails test`: `79 runs, 162 assertions, 0 failures, 0 errors, 0 skips` — no regressions in pre-existing tests (R5-AC5).
- Constraints respected: did NOT modify `image.rb` or `_image.html.erb`; did NOT touch other widgets; did NOT commit.

### T-008: Meter widget tests — DONE (2026-04-19)
- Created `/Users/augustingottlieb/tiler/test/lib/tiler/widgets/meter_test.rb` (19 tests, 34 assertions, all passing) following the existing `image_test.rb` `ActionView::TestCase` pattern.
- Setup seeds five `Tiler::DataRecord` rows on a fresh `Tiler::DataSource` with monotonically-spaced `recorded_at` (5h ago → 1h ago) and numeric `value` payloads `[100, 200, 300, 400, 500]`. Hand-computed aggregates: `last=500`, `avg=300`, `sum=1500`, `min=100`, `max=500` — all asserted exactly (R5-AC4 mapped).
- Registry assertions (R2-AC1 / R5-AC3): asserts `Tiler.widgets["meter"] == Tiler::Widgets::Meter`, `type=="meter"`, `label=="Meter"`, `partial=="tiler/widgets/meter"`, `query_class==Tiler::Widgets::MeterQuery`.
- Hash-shape (R2-AC2): `data.keys.sort == %i[value min max prefix suffix].sort` (exactly five keys, no extras).
- Min default (R2-AC3 / R2-AC4): `min` is `0.0` when omitted, follows `config["min"]` when set; `max` equals configured value.
- Aggregations (R2-AC5): all five aggregation enums covered as separate tests — `last`, `avg`, `sum`, `min`, `max` — each asserts the hand-computed expected value.
- Clamp (R2-AC6 / R2-AC7): below-min (last=500, min=600 → 600), above-max (last=500, max=400 → 400), in-range (last=500, max=1000 → 500) — all three branches covered.
- Empty data source (R2-AC8): fresh `create_data_source` with no records → `data.keys` still has all five keys; `data[:value] == nil`; partial renders without raising (`assert_nothing_raised`).
- Partial assertions (R2-AC9 / R2-AC10 / R5-AC5): `<svg>` element count == 1; `prefix="$"` + `suffix=" ms"` produce `$500` and `500 ms` patterns adjacent in the stripped-text rendering (R2-AC8 adjacency); blank prefix/suffix renders `500` without extras.
- Min-vs-max divergence (R2-AC9 SVG markup): renders panel where `value == min` (clamp pct=0, foreground `<path>` omitted via the `<% if pct > 0 %>` guard) vs `value == max` (clamp pct=1.0, foreground `<path>` present); asserts `refute_equal` on HTML AND `min_html.scan(/<path\b/).size < max_html.scan(/<path\b/).size`.
- Registry enumeration (R2-AC10 / R5-AC1): `Tiler.widgets.types` includes `"meter"` and `options_for_select` contains `["Meter", "meter"]`.
- Test result: `19 runs, 34 assertions, 0 failures, 0 errors, 0 skips` (run from project root via `bundle exec rails test test/lib/tiler/widgets/meter_test.rb` — same invocation pattern as `image_test.rb`).
- Constraints respected: did NOT modify `meter.rb` or `_meter.html.erb`; did NOT touch other widgets; did NOT commit.

### T-010 (comments side): Comments rotator visibility CSS + idempotent script guard — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/app/views/tiler/widgets/_comments.html.erb` inline `<script>` IIFE: added dataset-flag guard mirroring `_clock.html.erb`'s `tilerClockStarted` pattern. New gate: `if (!el || el.dataset.tilerCommentsStarted) return; el.dataset.tilerCommentsStarted = '1';` placed before the `querySelectorAll` so re-renders inside the same DOM (Turbo refresh) do not install duplicate `setInterval` timers (R6 / F-002).
- Appended to `/Users/augustingottlieb/tiler/app/assets/stylesheets/tiler/application.css`:
  ```css
  .tiler-comments .tiler-comment { display: none; }
  .tiler-comments .tiler-comment.tiler-comment-active { display: block; }
  ```
  This makes the rotator visually one-at-a-time: only the item carrying `tiler-comment-active` is `display: block` (R6 / F-001). The first item already gets `tiler-comment-active` from the `idx.zero?` branch in the partial loop.
- Added two tests in `comments_test.rb`:
  - `"exactly one item has tiler-comment-active class on initial render"` — counts class-attribute occurrences only via `/class="[^"]*\btiler-comment-active\b[^"]*"/` so JS `classList.add/remove('tiler-comment-active')` strings do not inflate the count.
  - `"rotator script gates with dataset flag"` — asserts both `tilerCommentsStarted` substring presence and exactly one `setInterval(` call per render.
- Constraints respected: did NOT touch image.rb, meter.rb, meter partial, image partial, image_test.rb, meter_test.rb, engine.rb, seed task. Did NOT commit.

### T-011 (comments side): URL scheme allowlist for comments avatar — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/lib/tiler/widgets/comments.rb`: added private `safe_url(u)` helper that returns the string only when it begins with `http://` or `https://`, else `nil`. Threaded through item map: `avatar: avatar_col.present? ? safe_url(payload[avatar_col]) : nil`. Image-side R7 work owned by parallel agent.
- The partial already gates `<img>` rendering with `item[:avatar].present?`, so a coerced-`nil` avatar simply skips the `<img>` tag — item still renders with quote and name (R7-AC4).
- Added three tests in `comments_test.rb`:
  - `"avatar with javascript: scheme is dropped"` → asserts `item[:avatar]` is `nil`.
  - `"avatar with data: scheme is dropped"` → asserts `item[:avatar]` is `nil`.
  - `"avatar with http(s) scheme passes through"` → asserts both `http://example.com/x.png` and `https://example.com/y.png` survive.
- File: scheme prefix not whitelisted (`file:`, `ftp:`, bare strings, etc.) all coerce to `nil` via the `start_with?` check — covered transitively by the same code path.

### T-013 (comments side): Drop blank-quote items — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/lib/tiler/widgets/comments.rb` `CommentsQuery#call`: after the `scope.map`, `items = items.reject { |i| i[:quote].to_s.strip.empty? }`. This drops items whose payload `quote_column` is missing (returns `nil` → `.to_s` → `""`), an empty string, or whitespace-only (R9 / F-005).
- The SQL `LIMIT` clamp still applies pre-map (it bounds records pulled, not surviving items), matching the existing contract — no change to the query layer. Empty-after-reject is fine because the partial's `data[:items].blank?` branch already renders a placeholder.
- Added test `"items with blank quote payload are dropped"` in `comments_test.rb`: seeds three records (real quote, missing-quote-key, empty-string quote), asserts only the real one survives.
- Meter-side R9 (`max == nil` placeholder) owned by parallel agent.

### T-014 (comments side): Replace tautological tests for comments name/avatar — DONE (2026-04-19)
- Replaced the no-op `assert_no_match(/.../missing/)` in `"items missing :name omit name node, items missing :avatar omit img"` (which always passed because the literal string `missing` never appears in the rendered HTML) with positive count assertions:
  - `assert_equal 3, html.scan(/class="tiler-comment-name"/).size` (Alice, Bob, Dee — "Third (no name)" record omits author).
  - `assert_equal 3, html.scan(/class="tiler-comment-avatar"/).size` (a/b/c.png — "Fourth (no avatar)" record omits pic).
- This now actually exercises R10 (and indirectly R3-AC11): the partial branches on `item[:name].present?` and `item[:avatar].present?` so missing-key items do drop the corresponding nodes. Meter-side R10 (`<text>` inner-text exact-equal `"500"`) owned by parallel agent.

### T-009: Comments widget tests — DONE (2026-04-19)
- Created `/Users/augustingottlieb/tiler/test/lib/tiler/widgets/comments_test.rb` co-located with the existing `image_test.rb` / `meter_test.rb` under `test/lib/tiler/widgets/`. `ActionView::TestCase` subclass so `render partial:` is available; `setup` builds one `@source` and `@dash` plus four `Tiler::DataRecord` rows with staggered `recorded_at` (3h, 2h, 1h, 30m ago). Payload keys are `quote/author/pic` so tests can vary `quote_column/name_column/avatar_column`; "Third" omits `author`, "Fourth" omits `pic` to exercise the missing-payload-key paths.
- Helpers: `panel_with(config)` builds a `widget_type: "comments"` panel via `create_panel` bound to `@source` with JSON-encoded config; `render_partial(panel)` renders `tiler/widgets/comments` with locals `panel:` and `data: panel.data`.
- 16 tests, 44 assertions, all green:
  1. Registry attributes (R3-AC1 / R5-AC2): `Tiler.widgets["comments"] == Tiler::Widgets::Comments`; `type=="comments"`, `label=="Comments"`, `partial=="tiler/widgets/comments"`, `query_class == Tiler::Widgets::CommentsQuery`.
  2. Query returns hash with `:items` and `:rotate_seconds` (R3-AC2).
  3. Each item hash has exactly the three keys `:quote, :name, :avatar` (R3-AC3).
  4. Items ordered by `recorded_at DESC` — first quote is "Fourth (no avatar)", last is "First" (R3-AC4 ordering).
  5. Default limit honored: items count `<= 10` (R3-AC4 default).
  6. `limit: 9999` clamped to `<= 100` (R3-AC4 upper bound).
  7. Missing `name_column` config → all items have `nil :name` (R3-AC5).
  8. Missing `avatar_column` config → all items have `nil :avatar` (R3-AC6).
  9. Missing payload key for present config column → that field is `nil` for the affected item; no raise (R3-AC5/AC6 payload variant).
  10. Empty data source → `{ items: [], rotate_seconds: <Integer> }` (R3-AC7).
  11. `:rotate_seconds` returns the configured positive integer; defaults to `8` when omitted, `0`, or negative (R3-AC8).
  12. Partial with non-empty items includes every quote text in the DOM (R3-AC9 / R5-AC4).
  13. Partial emits `data-tiler-rotate-interval="<rotate_seconds>"` on the root container (R3-AC10) — note the partial uses an inline `<script>` IIFE rather than a Stimulus controller (per T-005's deviation), but the data-attribute contract from R3-AC10 holds.
  14. Partial with mixed items (some missing :name / :avatar) renders successfully and does not double up image tags for the missing-pic record (R3-AC11).
  15. Empty data source partial render does not raise (R3-AC7 partial branch via `assert_nothing_raised`).
  16. Registry enumeration: `Tiler.widgets.types` includes `"comments"` and `options_for_select` contains `["Comments", "comments"]` so the panel-form dropdown surfaces the widget (R3-AC12 / R5-AC1).
- Run results from `/Users/augustingottlieb/tiler` root: `bundle exec rails test test/lib/tiler/widgets/comments_test.rb` → `16 runs, 44 assertions, 0 failures, 0 errors, 0 skips`. Full-suite `bundle exec rails test` → `114 runs, 240 assertions, 0 failures, 0 errors, 0 skips` — no regressions in pre-existing tests (R5-AC5).
- Note on test invocation: build-site said to run from `/Users/augustingottlieb/tiler/test/dummy` with `../../test/...` path, but `bundle exec rails test` from the dummy app cannot resolve `test_helper` via that relative path (LoadError). Same behavior as `image_test.rb` / `meter_test.rb`. Running from the project root works because the engine's Rakefile/test runner adds `test/` to the load path. Reported counts are from the root-run.
- Constraints respected: did NOT modify `comments.rb` or `_comments.html.erb`; did NOT touch other widgets; did NOT commit.

### T-011 (image side): URL scheme allowlist for image — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/lib/tiler/widgets/image.rb`: introduced `ALLOWED_SCHEMES = %w[http:// https://].freeze`; `#data` now routes `config["url"]` through private `safe_url(u)` which returns `""` for any value not prefixed with an allowlisted scheme. Existing `_image.html.erb` already branches on `data[:url].blank?` → placeholder path, so coercing to empty string downstream automatically renders the zero-`<img>` placeholder branch (R7-AC1, R7-AC2).
- Tests added in `/Users/augustingottlieb/tiler/test/lib/tiler/widgets/image_test.rb`: `javascript:alert(1)` → placeholder + zero `<img>`; `data:image/svg+xml,<svg></svg>` → placeholder + zero `<img>`; `http://example.com/x.png` and `https://example.com/y.png` → src passes through unchanged (R7-AC3, R7-AC5).
- Comments-avatar half of T-011 owned by parallel agent — not touched here.

### T-012 (image+meter sides): Enum whitelist — DONE (2026-04-19)
- Edited `image.rb`: `ALLOWED_FIT = %w[cover contain fill].freeze`; private `safe_fit(f)` substitutes `"contain"` for unknown values (R8-AC1).
- Edited `meter.rb`: `ALLOWED_AGG = %w[avg sum max min last].freeze` inside `MeterQuery`; aggregation route falls back to `"last"` for unknown values (R8-AC2).
- Tests: image — `fit: "contain; background:url(http://attacker)"` → `data[:fit] == "contain"` AND rendered HTML contains no `background:` substring; `fit: "stretch"` → `"contain"`. Meter — `aggregation: "drop_table"` → `value == 500.0` (the fixture's `last` value).
- Constraint R8-AC3 (no enum interpolation into `style=`/attribute names/etc) holds because partials still use the same hardcoded interpolation point and only allowlisted values can reach it.

### T-013 (meter side): Required-key error state for meter `max` — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/app/views/tiler/widgets/_meter.html.erb`: top-level branch `<% if data[:max].nil? %>` renders `<p class="tiler-muted">Configure a numeric <code>max</code>.</p>` and skips the SVG entirely. Else branch renders the original gauge unchanged (R9-AC1, R9-AC4).
- `MeterQuery` already returns `max: nil` when config omits or blanks `max` (numeric helper returns the `default` arg `nil`). No query change needed.
- Test: created a meter panel with `{value_column:"value", aggregation:"last"}` and no `max`; asserts `data[:max].nil?`, rendered HTML matches `/Configure a numeric/i`, and SVG count is 0.
- Comments side of T-013 (drop empty quotes) owned by parallel agent.

### T-014 (meter side): Replace tautological prefix/suffix assertions — DONE (2026-04-19)
- Removed the two tautology tests in `/Users/augustingottlieb/tiler/test/lib/tiler/widgets/meter_test.rb` ("partial renders prefix and suffix immediately adjacent to value" + "blank prefix and suffix emit nothing extra") that only used `assert_match(/500/, text)` — would pass even if the partial emitted `nil.inspect`.
- Replaced with two positive assertions using inner-text capture from the SVG `<text>` node: `text_node = html[/<text[^>]*>([^<]*)<\/text>/, 1]`; blank-prefix/suffix case asserts `text_node == "500"`; populated case asserts `text_node == "$500 ms"` (R10-AC2).
- Comments side of T-014 (positive count assertions on `tiler-comment-name` / `tiler-comment-avatar`) owned by parallel agent.

### Tier 4 (image+meter cuts) Validation — 2026-04-19
- `bundle exec rails test test/lib/tiler/widgets/image_test.rb test/lib/tiler/widgets/meter_test.rb` → `35 runs, 73 assertions, 0 failures, 0 errors, 0 skips`.
- Full-suite `bundle exec rails test` → `127 runs, 263 assertions, 0 failures, 0 errors, 0 skips` — no regressions.
- Did NOT commit (per dispatch instructions). Did NOT touch comments.rb, _comments.html.erb, comments_test.rb, application.css, _image.html.erb, engine.rb, or seed task — those are the parallel agent's lane.

### T-019: Unify safe_url contract across image + comments (F-015, F-016, F-019) — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/lib/tiler/widgets/image.rb`: rewrote `safe_url` to (a) `.strip` leading/trailing whitespace, (b) return `nil` for empty/rejected (was `""` previously — F-015 inconsistency), (c) downcase only the first 8 chars (`https://` is 8 chars) for case-insensitive scheme check without altering the URL path which is RFC 3986 case-sensitive. Removed now-unused `ALLOWED_SCHEMES` constant. Image partial uses `data[:url].blank?` so coercion from `""` to `nil` is behavior-equivalent.
- Edited `/Users/augustingottlieb/tiler/lib/tiler/widgets/comments.rb`: replaced `CommentsQuery#safe_url` body with the same identical helper (strip + 8-char downcased prefix check + nil-on-reject). Both widgets now share the exact same safe_url contract.
- Tests added to `image_test.rb`: `"url with leading whitespace is trimmed and accepted"`, `"url with uppercase scheme is accepted (case-insensitive)"`, `"url returns nil when rejected (not empty string)"`. The trim test asserts the trimmed URL appears in the rendered `src=` attribute (no surrounding whitespace). The uppercase-scheme test confirms `HTTPS://example.com/x.png` passes through unchanged (only the prefix-check is case-insensitive; the rest of the URL is preserved verbatim because path is case-sensitive). The nil-rejection test asserts `panel.data[:url]` is `nil` (not `""`) when scheme rejected — proves F-015 fixed.
- Tests added to `comments_test.rb`: `"avatar with leading whitespace is trimmed and accepted"` and `"avatar with uppercase scheme is accepted (case-insensitive)"` — same contracts as image side, applied to the comments avatar field.
- Resolves F-015 (API consistency: both return nil), F-016 (whitespace tolerated), F-019 (case-insensitive scheme).

### T-020a: safe_fit nil-value defensive test (F-017) — DONE (2026-04-19)
- Test-only addition to `image_test.rb`: `"fit with nil value falls back to contain"` — explicitly passes `fit: nil` in JSON config (deserializes to nil after `JSON.parse`), asserts `panel.data[:fit] == "contain"`. Exercises the `safe_fit(nil)` path which was previously untested but already handled correctly by the existing `f.to_s` coercion (nil → "" → not in ALLOWED_FIT → fallback to "contain"). No source change.
- Resolves F-017.

### T-020b: Comments pluck perf optimization (F-011) — DONE (2026-04-19)
- Refactored `/Users/augustingottlieb/tiler/lib/tiler/widgets/comments.rb` `CommentsQuery#call`: replaced `scope.map { |record| ... parse_payload(record) ... }` (loaded full ActiveRecord rows then JSON-parsed in Ruby) with a `.pluck(*cols)` call where `cols` is built from the `Tiler::Query::Base#json_extract` SQLite JSON1 helper. SQLite extracts the three payload keys directly during the scan, returning a 2D array of strings/nils — no AR row instantiation, no JSON.parse round-trip per row.
- Column array construction: `cols = [Arel.sql(json_extract(quote_col))]`; name and avatar are conditionally `Arel.sql(json_extract(col))` if config column is present AND `safe_col?` (alphanumeric+underscore guard from base), else `Arel.sql("NULL")` placeholder so the result rows always have 3 elements at fixed indices. The outer `safe_col?(quote_col)` guard already gates the whole branch, so the inner `safe_col?` calls protect name/avatar against payload-key injection independently.
- Result mapping: `row[0].to_s` for quote (preserves "" → reject branch downstream), `row[1]` passthrough for name (no validation), `safe_url(row[2])` for avatar (existing scheme allowlist).
- Dropped private `parse_payload(record)` helper — no longer used after the AR-row iteration was removed.
- Kept `safe_url` helper because it still gates the avatar (single call site survives the refactor).
- Data-shape contract unchanged: 3-key item hashes (`:quote, :name, :avatar`), same ordering (`recorded_at DESC`), same limit clamping, same blank-quote rejection, same rotate_seconds default. All 21 pre-existing comments tests pass unchanged after the refactor — confirms the contract is preserved.
- Resolves F-011.

### Tier 6 P3 Batch B Validation — 2026-04-19
- `bundle exec rails test test/lib/tiler/widgets/` → `70 runs, 151 assertions, 0 failures, 0 errors, 0 skips` (was 63 → +7 new tests: 4 image, 3 comments; +1 over the dispatch's "~6" estimate due to the explicit safe_fit nil test).
- Full-suite `bundle exec rails test` → `140 runs, 287 assertions, 0 failures, 0 errors, 0 skips` — no regressions in pre-existing tests.
- Constraints respected: did NOT touch meter.rb, meter partial, seed task, kit doc, application.css (Agent A's lane). Did NOT commit.

### T-015: Close R7/R8 test-coverage gaps (F-013, F-014) — DONE (2026-04-19)
- Test-only task closing P2 gaps from round-2 inspection: R7 (file:/bare-string URL coverage) and R8 (blank/nil aggregation fallback). Zero source changes.
- `image_test.rb`: appended two tests — `"url with file scheme renders placeholder"` (asserts zero `<img>` + `tiler-muted` placeholder for `file:///etc/passwd`) and `"url with no scheme (bare string) renders placeholder"` (asserts zero `<img>` for `"x.png"`). Both rely on existing `safe_url` allowlist in `image.rb` (T-011) which coerces non-http(s) URLs to `""` → partial's `data[:url].blank?` branch.
- `comments_test.rb`: appended two tests — `"avatar with file scheme is dropped"` and `"avatar with no scheme (bare string) is dropped"` — both assert `panel.data[:items].first[:avatar]` is `nil` for `file:///etc/passwd` and `"x.png"` payloads respectively. Rely on `CommentsQuery#safe_url` (T-011 comments side) which whitelists only `http://`/`https://`.
- `meter_test.rb`: appended two tests — `"blank aggregation falls back to last"` (passes `aggregation: ""`, asserts `data[:value] == 500.0`) and `"nil aggregation falls back to last"` (omits `aggregation` key entirely from config, asserts `data[:value] == 500.0`). Both rely on `MeterQuery`'s `ALLOWED_AGG` whitelist (T-012) substituting `"last"` for blank/missing values, plus the fixture's most-recent (1h ago) record with `value: 500.0`.
- Run results from `/Users/augustingottlieb/tiler` root: `bundle exec rails test test/lib/tiler/widgets/` → `63 runs, 135 assertions, 0 failures, 0 errors, 0 skips` (was 57 → +6 new tests, exactly matching dispatch expectation).
- Constraints respected: zero source modifications (image.rb, meter.rb, comments.rb, partials, css, engine, seed all untouched). Did NOT commit.

### T-016: Meter SVG a11y (F-010) — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/app/views/tiler/widgets/_meter.html.erb`: added five aria attrs to the `<svg>` opening tag inside the `data[:max].present?` branch only — `role="img"`, `aria-label="<%= panel.title.presence || "Gauge" %>"`, `aria-valuemin="<%= mn %>"`, `aria-valuemax="<%= mx %>"`, `aria-valuenow="<%= has_value ? v.to_f : mn %>"`. Placeholder branch (`<p class="tiler-muted">`) untouched per dispatch.
- Used `panel.title.presence || "Gauge"` so empty-title panels still get a sensible accessible label.
- Added test `"rendered SVG carries aria meter attrs"` in `meter_test.rb` after R9 placeholder test — asserts `role="img"`, `aria-valuemin=`, `aria-valuemax=`, `aria-valuenow=` are present in rendered HTML.
- Test result: meter file 23 → 24 runs, 44 → 45 assertions, all green.

### T-017: Kit doc fix (F-009) — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/context/kits/cavekit-widgets-smashing-parity.md`: replaced three occurrences of `Tiler.widgets.lookup("...")` with `Tiler.widgets["..."]` in R1-AC1 / R2-AC1 / R3-AC1 — matches actual `Tiler::WidgetRegistry` API which exposes `[]`/`fetch`, not `lookup`.
- Bumped frontmatter `last_edited` to `2026-04-20T00:00:00Z`.
- Appended Changes entry: `- 2026-04-20: Fixed kit prose — Tiler.widgets.lookup → Tiler.widgets[...] (registry has [] / fetch, not lookup). Closes F-009.`
- Doc-only; no source/test changes.

### T-018: Seed quotes data source (F-012) — DONE (2026-04-19)
- Edited `/Users/augustingottlieb/tiler/lib/tasks/tiler_tasks.rake`:
  1. Added `quotes_source = Tiler::DataSource.find_or_create_by!(slug: "demo_quotes")` block alongside `source` (demo_requests), schema `[quote, author, avatar]`, ingestion `[manual]`.
  2. Retargeted the existing `dash.panels.create!(title: "Recent comments", ...)` line: changed `data_source: source` → `data_source: quotes_source`; expanded config to `{ quote_column: "quote", name_column: "author", avatar_column: "avatar", time_window: "7d", limit: 10, rotate_seconds: 5 }`.
  3. Added `if quotes_source.data_records.empty?` block seeding 5 sample quote records (Kent Beck, Donald Knuth, Leonardo da Vinci, John Johnson, Cory House) with pravatar.cc avatars, staggered `recorded_at` (1h..5h ago).
- Verified via `cd test/dummy && rails db:reset && rails tiler:seed`: clean exit with `Tiler seeded. Visit /tiler/dashboards/demo`.
- Verified via `rails runner`: `demo_quotes` source exists with 5 records; comments panel `data_source.slug == "demo_quotes"`; `panel.data` returns 5 items each with `{quote:, name:, avatar:}` populated correctly.

### Tier 6 P3 Batch A Validation — 2026-04-19
- `bundle exec rails test test/lib/tiler/widgets/meter_test.rb` → `24 runs, 45 assertions, 0 failures, 0 errors, 0 skips` (was 23/44 — +1 aria test).
- All-widgets: `bundle exec rails test test/lib/tiler/widgets/` → `70 runs, 151 assertions, 0 failures, 0 errors, 0 skips`.
- Full-suite: `bundle exec rails test` → `140 runs, 287 assertions, 0 failures, 0 errors, 0 skips` — no regressions.
- Seed: `cd test/dummy && rails db:reset && rails tiler:seed` → clean.
- Constraints respected: did NOT touch image.rb, comments.rb, image_test.rb, comments_test.rb (Agent B's lane). Did NOT commit.
