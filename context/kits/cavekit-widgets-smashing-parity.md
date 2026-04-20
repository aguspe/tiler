---
created: 2026-04-19T00:00:00Z
last_edited: 2026-04-19T18:00:00Z
---

# Cavekit: Widgets — Smashing Parity

## Scope

Adds three new built-in widgets to the Tiler engine — `image`, `meter`, and `comments` — bringing the widget catalog to parity with Smashing's default set. Covers widget classes, view partials, engine registration, demo seed entries, and tests. Each widget conforms to Tiler's existing widget contract:

- Widget class lives in `lib/tiler/widgets/<name>.rb`, subclasses `Tiler::Widget`, sets `self.type/partial/label/query_class`, and self-registers via `Tiler.widgets.register(...)`.
- Data-source-backed widgets define a sibling `Tiler::Query::Base` subclass whose `#call` returns the hash/array consumed by the partial.
- Config-only widgets set `query_class = nil` and expose a `#data` method that derives display state from `panel.config` (parsed JSON).
- Partial lives in `app/views/tiler/widgets/_<name>.html.erb` and is rendered with locals `panel:` and `data:` (data is `nil` for config-only widgets when no query runs, or the hash returned by `#data` / the query class).
- Widget files are required from the `tiler.register_builtin_widgets` initializer in `lib/tiler/engine.rb`.

## Requirements

### R1: Image widget (config-only)

**Description:** A config-only widget that renders a single image inside the panel area, with no data-source binding. Mirrors the existing `clock`, `text`, and `iframe` widgets.

**Config keys (read from `panel.config` JSON):**
- `url` (required, string) — image source URL.
- `alt` (optional, string) — accessible alt text.
- `fit` (optional, enum `cover` | `contain` | `fill`, default `contain`) — controls the image's CSS `object-fit` behavior so it scales to the panel.

**Acceptance Criteria:**
- [ ] `Tiler.widgets.lookup("image")` returns a registered widget class whose `type == "image"`, `label == "Image"`, `query_class == nil`, and `partial == "tiler/widgets/image"`.
- [ ] Instantiating the widget with `config = { "url" => "https://example.com/x.png", "alt" => "x", "fit" => "cover" }` and calling `#data` returns a hash containing `url`, `alt`, and `fit` with the supplied values.
- [ ] When `config["fit"]` is missing or blank, `#data[:fit]` equals `"contain"`.
- [ ] Rendering the partial `tiler/widgets/image` with a panel whose config has a non-blank `url` produces output containing exactly one `<img` tag whose `src` attribute equals `data[:url]`.
- [ ] The rendered `<img>` tag exposes `data[:fit]` to CSS (e.g., via an `object-fit` style or a class encoding the value) so a panel-sized image honors the configured fit mode.
- [ ] Rendering the partial with a panel whose config has a blank or missing `url` does not raise and produces a placeholder element (e.g., a `<p class="tiler-muted">` or equivalent empty-state node) and zero `<img>` tags.
- [ ] When `alt` is provided in config, the rendered `<img>` tag's `alt` attribute equals that value; when omitted, the `alt` attribute is present and empty (`alt=""`).
- [ ] The widget appears in the panel-form widget-type dropdown (the dropdown is populated from `Tiler.widgets.all` / equivalent registry enumeration; "Image" is one of the visible options).

**Dependencies:** R4 (engine registration).

---

### R2: Meter widget (gauge, data-source-backed)

**Description:** A data-source-backed widget that aggregates numeric values from a data source over a time window and displays the result as a gauge between configurable `min` and `max` bounds. Follows the same query-class pattern as `metric` and `number_with_delta`.

**Config keys (read from `panel.config` JSON):**
- `value_column` (required, string) — JSON payload key holding the numeric value on each `Tiler::DataRecord`.
- `aggregation` (optional, enum `avg` | `sum` | `max` | `min` | `last`, default `last`) — how to combine matching records.
- `time_window` (optional, string like `24h` / `7d` / `30d`, default `24h`) — how far back to look (parsed by the same helper used by other data-backed widgets).
- `min` (optional, numeric, default `0`) — gauge floor.
- `max` (required, numeric) — gauge ceiling.
- `prefix` (optional, string) — text rendered before the value (e.g., `"$"`).
- `suffix` (optional, string) — text rendered after the value (e.g., `"%"`).

**Acceptance Criteria:**
- [ ] `Tiler.widgets.lookup("meter")` returns a registered widget class whose `type == "meter"`, `label == "Meter"`, `partial == "tiler/widgets/meter"`, and `query_class` is a subclass of `Tiler::Query::Base`.
- [ ] Calling the query class's `#call` against a data source containing records with numeric `value_column` payloads returns a hash with exactly the keys `:value`, `:min`, `:max`, `:prefix`, `:suffix`.
- [ ] The returned `:min` defaults to `0` when `config["min"]` is absent and equals the configured numeric value otherwise; `:max` equals the configured numeric value.
- [ ] The returned `:value` is clamped into the inclusive range `[:min, :max]`: aggregated values below `:min` return `:min`; aggregated values above `:max` return `:max`; in-range values pass through unchanged.
- [ ] Each `aggregation` enum value (`avg`, `sum`, `max`, `min`, `last`) produces a numerically correct aggregate over the test fixture records (matches a hand-computed value); `last` returns the value from the most recent `recorded_at` record.
- [ ] When the data source has zero matching records in the time window, `#call` returns the same five-key hash with `:value` either equal to `:min` or `nil`, and rendering the partial with that hash does not raise.
- [ ] Rendering the partial `tiler/widgets/meter` with a populated data hash produces output containing one `<svg` element representing the gauge arc.
- [ ] Rendering the partial includes the formatted value text with `:prefix` immediately before and `:suffix` immediately after the value (no intervening characters); when `:prefix` or `:suffix` is blank, no extra characters are rendered.
- [ ] Rendering the partial with `:value` equal to `:min` and with `:value` equal to `:max` both succeed without raising and visually represent the two extremes (e.g., distinct arc geometries — verifiable by checking that the rendered SVG markup differs between the two cases).
- [ ] The widget appears in the panel-form widget-type dropdown.

**Dependencies:** R4 (engine registration). Reuses the time-window parsing and aggregation helpers exposed by `Tiler::Query::Base` (same contract used by `metric` and `list`).

---

### R3: Comments widget (rotating quotes, data-source-backed)

**Description:** A data-source-backed widget that pulls recent records from a data source and displays them one at a time, cycling on a client-side timer (no server round-trips between rotations within a single dashboard refresh interval).

**Config keys (read from `panel.config` JSON):**
- `quote_column` (required, string) — JSON payload key holding the quote text.
- `name_column` (optional, string) — JSON payload key holding the author name.
- `avatar_column` (optional, string) — JSON payload key holding the avatar URL.
- `time_window` (optional, string, default `7d`).
- `limit` (optional, integer, default `10`) — maximum number of comments to rotate through.
- `rotate_seconds` (optional, integer, default `8`) — interval between rotations on the client.

**Acceptance Criteria:**
- [ ] `Tiler.widgets.lookup("comments")` returns a registered widget class whose `type == "comments"`, `label == "Comments"`, `partial == "tiler/widgets/comments"`, and `query_class` is a subclass of `Tiler::Query::Base`.
- [ ] Calling the query class's `#call` returns a hash with at least the keys `:items` and `:rotate_seconds`.
- [ ] `:items` is an `Array` of hashes; each item hash has exactly the keys `:quote`, `:name`, `:avatar`.
- [ ] Items are ordered by `recorded_at` descending (newest first) and the array length is at most `config["limit"]` (defaulting to `10` when unset, clamped to a sane upper bound such as `100`).
- [ ] When `config["name_column"]` is absent or the underlying payload key is missing on a record, that item's `:name` is `nil` (or empty string) — `#call` does not raise.
- [ ] When `config["avatar_column"]` is absent or the underlying payload key is missing on a record, that item's `:avatar` is `nil` (or empty string) — `#call` does not raise.
- [ ] When the data source has zero matching records, `#call` returns `{ items: [], rotate_seconds: <int> }` and rendering the partial with that hash does not raise.
- [ ] `:rotate_seconds` equals `config["rotate_seconds"]` when set to a positive integer, otherwise `8`.
- [ ] Rendering the partial `tiler/widgets/comments` with a non-empty items array produces output containing all item quote texts in the DOM (the rotation is purely a client-side display concern; all items are present in markup).
- [ ] The rendered partial wires up a Stimulus controller (or equivalent JS hook already used elsewhere in Tiler) whose configured rotation interval, exposed as a data attribute, equals `data[:rotate_seconds]`.
- [ ] When an item has no `:name`, the rendered DOM for that item omits the author-name node (or renders it empty); when an item has no `:avatar`, the rendered DOM omits the avatar `<img>` (or substitutes a default avatar element) — neither case raises.
- [ ] The widget appears in the panel-form widget-type dropdown.

**Dependencies:** R4 (engine registration). Stimulus is already a hard dependency of the engine (`require "stimulus-rails"` in `lib/tiler/engine.rb`).

---

### R4: Engine registration, install, and seed wiring

**Description:** The three new widgets must be discoverable through the same auto-load and seed paths as the existing built-ins, so a fresh install or a run of `bin/rails tiler:seed` exposes them with no extra steps.

**Acceptance Criteria:**
- [ ] `lib/tiler/engine.rb`'s `tiler.register_builtin_widgets` initializer requires `tiler/widgets/image`, `tiler/widgets/meter`, and `tiler/widgets/comments` (in addition to the existing requires).
- [ ] After Rails boot, `Tiler.widgets.all.map(&:type)` (or the equivalent enumeration the engine exposes) includes `"image"`, `"meter"`, and `"comments"`.
- [ ] `lib/tasks/tiler_tasks.rake`'s `tiler:seed` task creates one demo panel per new widget on the `demo` dashboard when the dashboard has no panels:
  - One panel with `widget_type == "image"`, a non-blank `url` in its config, and no `data_source`.
  - One panel with `widget_type == "meter"`, `data_source == demo_requests`, and a config containing at least `value_column`, `max`, and a `time_window`.
  - One panel with `widget_type == "comments"`, `data_source == demo_requests`, and a config containing at least `quote_column` and a `time_window`.
- [ ] Each seeded panel has non-overlapping grid coords (`x`, `y`, `width`, `height`) within the existing 12-column layout and does not overlap any pre-existing seeded panel.
- [ ] After running `bin/rails tiler:seed` against a fresh dummy app, visiting `/tiler/dashboards/demo` renders all three new panels with no server-side errors (HTTP 200 for the dashboard show action and no exceptions in the log).
- [ ] No new database migrations are introduced; all configuration is stored in the existing `tiler_panels.config` JSON column.

**Dependencies:** R1, R2, R3.

---

### R5: Tests

**Description:** Each new widget gets an automated test file colocated with the existing widget-related tests under `test/lib/tiler/`. Tests run under the dummy app's Rails test harness.

**Acceptance Criteria:**
- [ ] One test file exists per new widget (e.g., `test/lib/tiler/widgets/image_test.rb`, `meter_test.rb`, `comments_test.rb`); the directory is created if it does not already exist.
- [ ] The image test asserts: registry lookup returns the expected class; `#data` returns the expected hash for typical config; `#data[:fit]` defaults to `"contain"` when omitted; rendering the partial with a valid `url` includes an `<img>` tag whose `src` matches; rendering with a blank `url` does not raise and produces zero `<img>` tags.
- [ ] The meter test asserts: registry lookup returns the expected class; the query class returns a hash with the documented keys for a fixture data source; out-of-range aggregated values are clamped into `[:min, :max]`; an empty data source yields a non-raising hash; rendering the partial with a populated hash produces an `<svg>` and includes prefix/suffix text around the value.
- [ ] The comments test asserts: registry lookup returns the expected class; the query class returns a hash with `:items` and `:rotate_seconds`; items are ordered newest-first and respect `limit`; missing `name_column` / `avatar_column` config values do not raise; an empty data source yields `{ items: [], rotate_seconds: <int> }`; rendering the partial with a non-empty items array includes all quote texts in the DOM.
- [ ] All new tests pass under `bundle exec rails test` executed from `/Users/augustingottlieb/tiler/test/dummy`.
- [ ] Existing tests under `test/lib/tiler/` (`configuration_test.rb`, `query_test.rb`, `widget_registry_test.rb`) continue to pass after the changes.

**Dependencies:** R1, R2, R3, R4.

---

### R6: Comments rotation must be visually one-at-a-time and idempotent across refreshes

**Description:** The comments widget's headline behavior — rotating one quote at a time — must be visible to the end user and must not leak `setInterval` timers when the dashboard's polling refresh re-renders the partial. Discovered via inspection finding F-001 (rotator has no CSS so all items show simultaneously) and F-002 (inline `<script>` re-runs every Turbo frame reload, accumulating timers).

**Acceptance Criteria:**
- [ ] CSS rules in `app/assets/stylesheets/tiler/application.css` hide `.tiler-comment` by default and show only `.tiler-comment.tiler-comment-active`.
- [ ] On initial render of the partial with N items, exactly one item carries the `tiler-comment-active` class (the first item).
- [ ] A test asserts that after rendering, exactly one item element has the `tiler-comment-active` class and the other N−1 do not.
- [ ] The inline `<script>` IIFE is gated by an element-level dataset flag (mirroring `_clock.html.erb`'s `tilerClockStarted` pattern) so re-rendering the partial within the same DOM does not install duplicate intervals.
- [ ] A test asserts the partial output contains both the dataset flag set/check pattern and a single `setInterval(` call per render.

**Dependencies:** R3 (Comments widget).

---

### R7: User-supplied URL fields must be scheme-restricted to http(s)

**Description:** `image.url` and any avatar URL in the comments widget's payload are interpolated into `<img src="...">` and equivalent contexts. Without scheme restriction, panel editors (lower trust) can inject `javascript:`, `data:`, or `file:` URIs that affect dashboard viewers (higher trust). Discovered via inspection finding F-008.

**Acceptance Criteria:**
- [ ] Image widget with `config["url"] = "javascript:alert(1)"` renders the placeholder branch (zero `<img>` tags), not an `<img src="javascript:...">`.
- [ ] Image widget with `config["url"] = "data:text/html;base64,..."` renders the placeholder branch.
- [ ] Image widget passes through `http://` and `https://` URLs unchanged.
- [ ] Comments partial omits the avatar `<img>` tag for any item whose `:avatar` is non-blank but not `http(s)://`-prefixed (the item itself still renders, just without an avatar).
- [ ] Tests cover `javascript:`, `data:`, `file:`, and bare-string inputs for both widgets, plus the http(s) pass-through cases.

**Dependencies:** R1 (Image widget), R3 (Comments widget).

---

### R8: Enum-typed config keys must be whitelisted in widget code

**Description:** Any cavekit-documented enum (e.g., `image.fit ∈ {cover, contain, fill}`, `meter.aggregation ∈ {avg, sum, max, min, last}`) must be enforced at the widget layer. Unknown enum values fall back to the documented default and never reach a `style="..."` or attribute interpolation that could enable injection. Discovered via inspection finding F-003 (CSS injection through unvalidated `fit`).

**Acceptance Criteria:**
- [ ] `Image#data` rejects any `config["fit"]` value outside `%w[cover contain fill]` and substitutes `"contain"`. Test: setting `fit: "contain; background:url(x)"` yields `data[:fit] == "contain"` and the rendered partial contains no `background:` substring.
- [ ] `MeterQuery` rejects any `config["aggregation"]` value outside `%w[avg sum max min last]` and substitutes `"last"` (or whatever the documented default is). Test: setting `aggregation: "drop_table"` yields a normal `last` aggregate.
- [ ] No enum value is interpolated into a `style="..."`, an attribute name, an HTML class, or any other context where unvalidated input could affect rendering or styling outside the panel's own bounds.

**Dependencies:** R1 (Image), R2 (Meter).

---

### R9: Required config keys must produce a clear user-visible error state when missing

**Description:** Cavekit-marked "required" keys (`image.url`, `meter.value_column`, `meter.max`, `comments.quote_column`) must produce an actionable, viewer-visible message when missing — not a blank or default-valued render that hides the misconfiguration. Discovered via inspection findings F-004 (meter `max` missing → blank gauge) and F-005 (comments empty quotes from missing payload key pollute rotation).

**Acceptance Criteria:**
- [ ] Meter partial rendered with a data hash whose `:max` is `nil` displays a placeholder message (e.g., `"Configure max"` or equivalent) rather than a silent blank gauge.
- [ ] CommentsQuery filters out items whose `:quote` is blank (missing payload key, parse failure, or empty string) so they do not occupy slots in the rotation.
- [ ] A test asserts that seeding records with a missing `quote_column` payload key yields a `:items` array that does not contain those records.
- [ ] A test asserts that the meter partial with `data[:max] == nil` contains the configuration-error placeholder text and zero filled-arc geometry.

**Dependencies:** R2 (Meter), R3 (Comments).

---

### R10: Test assertions must verify behavior, not tautologies

**Description:** Two existing tests (T-008 prefix/suffix, T-009 missing-name/avatar) pass without actually exercising the cavekit acceptance criterion. Replace tautological assertions with positive, behavior-bound checks. Discovered via inspection findings F-006 and F-007.

**Acceptance Criteria:**
- [ ] Comments test "items missing :name omit name node, items missing :avatar omit img" replaces the no-op `assert_no_match(/.../missing/)` with a positive count: assert the rendered HTML contains exactly N `class="tiler-comment-name"` occurrences where N equals the count of fixture items with a non-blank `:name`, and the same for `class="tiler-comment-avatar"`.
- [ ] Meter test "blank prefix and suffix emit nothing extra" extracts the inner text of the SVG `<text>` node and asserts it equals exactly `"500"` (or the canonical formatted value) — not just `assert_match(/500/)`.

**Dependencies:** R5 (Tests).

---

## Out of Scope

- Custom CSS theming for the new widgets beyond the styling already shared by existing widgets in `app/assets/stylesheets/tiler/application.css`. New widgets may add minimal class hooks but will not introduce a redesigned visual system.
- Server-Sent Events, ActionCable, or any push-based update mechanism. Dashboards continue to refresh on the existing `dashboard.refresh_seconds` polling cadence; the comments widget's intra-refresh rotation is purely client-side cycling over already-loaded items.
- Image upload or file attachment. The image widget accepts a remote `url` only — no Active Storage integration, no local file handling.
- A widget marketplace, plug-in discovery, or external widget registry. Widgets remain in-engine and required by `lib/tiler/engine.rb`.
- Database schema changes. No new migrations; everything piggybacks on the existing `tiler_panels.config` JSON column and `tiler_data_records.payload` JSON column.
- New aggregation primitives beyond what `Tiler::Query::Base` already exposes (other than the meter widget consuming `last`, which must be available through the existing query helpers — if it is not, that is a defect in `Tiler::Query::Base` to be addressed there, not here).
- Backfilling Smashing-style theming, dashing.js compatibility, or any migration tooling for users coming from Smashing/Dashing.

## Cross-References

- See also: `cavekit-overview.md` for the overall index.
- Existing widget contract reference (read before implementing):
  - Config-only pattern: `lib/tiler/widgets/text.rb`, `lib/tiler/widgets/iframe.rb`, `lib/tiler/widgets/clock.rb` and their partials under `app/views/tiler/widgets/`.
  - Data-source-backed pattern: `lib/tiler/widgets/metric.rb`, `lib/tiler/widgets/list.rb` and their partials.
  - Registry / auto-load: `lib/tiler/engine.rb` (the `tiler.register_builtin_widgets` initializer).
  - Seed pattern: `lib/tasks/tiler_tasks.rake` (`tiler:seed` task).
  - Query helpers: `Tiler::Query::Base` (used by all data-source-backed widgets for time-window filtering and aggregation).

## Changes

- 2026-04-19: Added R6 (rotation visibility + idempotency) — discovered during inspection, findings F-001 (no CSS for rotator) and F-002 (timer leak on Turbo refresh).
- 2026-04-19: Added R7 (URL scheme allowlist) — discovered during inspection, finding F-008 (`javascript:`/`data:` URIs accepted).
- 2026-04-19: Added R8 (enum whitelist) — discovered during inspection, finding F-003 (CSS injection via `fit` attribute).
- 2026-04-19: Added R9 (required-key error states) — discovered during inspection, findings F-004 (meter `max` silent) and F-005 (empty-quote pollution).
- 2026-04-19: Added R10 (test tautology fixes) — discovered during inspection, findings F-006 and F-007.
