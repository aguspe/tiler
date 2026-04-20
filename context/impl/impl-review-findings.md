---
created: 2026-04-19T18:00:00Z
last_edited: 2026-04-19T18:00:00Z
---

# Review Findings

Build site: context/plans/build-site.md
Source: `/ck:check` peer review of T-001..T-009.

| Finding | Severity | File(s) | Status | Resolution Task |
|---------|----------|---------|--------|------------------|
| F-001: Comments rotator has no CSS — all items visible permanently | P1 | app/views/tiler/widgets/_comments.html.erb, app/assets/stylesheets/tiler/application.css | NEW | T-010 (R6) |
| F-002: Inline `<script>` re-runs each Turbo refresh, leaks setInterval timers | P1 | app/views/tiler/widgets/_comments.html.erb | NEW | T-010 (R6) |
| F-003: `image.fit` not whitelisted → CSS injection via `style` attribute | P1 | lib/tiler/widgets/image.rb, app/views/tiler/widgets/_image.html.erb | NEW | T-012 (R8) |
| F-004: Meter `max` documented required but silently nil → blank gauge | P2 | lib/tiler/widgets/meter.rb, app/views/tiler/widgets/_meter.html.erb | NEW | T-013 (R9) |
| F-005: CommentsQuery emits empty `<blockquote>` for missing/blank quote payload | P2 | lib/tiler/widgets/comments.rb | NEW | T-013 (R9) |
| F-006: Comments name/avatar test uses tautological regex (matches non-existent `missing` literal) | P2 | test/lib/tiler/widgets/comments_test.rb | NEW | T-014 (R10) |
| F-007: Meter prefix/suffix test only `assert_match(/500/)` — passes even with `nil.inspect` | P2 | test/lib/tiler/widgets/meter_test.rb | NEW | T-014 (R10) |
| F-008: `image.url` and avatar src accept `javascript:`/`data:`/`file:` schemes | P2 | lib/tiler/widgets/image.rb, lib/tiler/widgets/comments.rb, partials | NEW | T-011 (R7) |
| F-009: Cavekit prose mentions `Tiler.widgets.lookup(...)` — registry has no `lookup` | P3 | context/kits/cavekit-widgets-smashing-parity.md | DEFERRED | doc-only; revise next pass |
| F-010: Meter SVG missing `role="img"` + aria-valuemin/now/max | P3 | app/views/tiler/widgets/_meter.html.erb | DEFERRED | a11y; future kit |
| F-011: CommentsQuery loads full ARrows + JSON-parses in Ruby | P3 | lib/tiler/widgets/comments.rb | DEFERRED | bounded by limit=100; low impact |
| F-012: Demo seed uses `quote_column: "status"` → rotation cycles "ok"/"error" not real quotes | P3 | lib/tasks/tiler_tasks.rake | DEFERRED | demo-UX cosmetic |

## Resolution Plan

T-010 → T-014 added to build site Tier 4. All five tasks parallelizable.
Run `/ck:make` to apply.

P3 items (F-009..F-012) deferred — not blocking. Pick up later if user wants.

---

## Round 2 (post Tier 4) — 2026-04-19 18:30Z

Previous F-001..F-008 all CONFIRMED FIXED.

| Finding | Severity | File(s) | Status | Resolution Task |
|---------|----------|---------|--------|------------------|
| F-013: R7 enumerates `file:` + bare-string scheme tests for both widgets; not present | P2 | test/lib/tiler/widgets/{image,comments}_test.rb | NEW | T-015 |
| F-014: Meter aggregation `presence || "last"` branch (blank/nil) untested | P2 | test/lib/tiler/widgets/meter_test.rb | NEW | T-015 |
| F-015: image safe_url returns `""`; comments safe_url returns `nil` — API inconsistency | P3 | lib/tiler/widgets/{image,comments}.rb | DEFERRED | cosmetic |
| F-016: safe_url no `.strip` before scheme check — leading whitespace silently rejected | P3 | lib/tiler/widgets/{image,comments}.rb | DEFERRED | UX papercut |
| F-017: `safe_fit(nil)` defensive path untested | P3 | test/lib/tiler/widgets/image_test.rb | DEFERRED | low value |
| F-018: theoretical Turbo-morph timer leak (same as pre-existing clock widget) | P3 | app/views/tiler/widgets/{_comments,_clock}.html.erb | DEFERRED | not a regression |
| F-019: scheme allowlist case-sensitive — `HTTPS://` rejected vs RFC 3986 | P3 | lib/tiler/widgets/{image,comments}.rb | DEFERRED | rare in practice |

## Resolution Plan Round 2

T-015 added to close F-013 + F-014 (test-only, no source change).

