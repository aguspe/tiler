---
created: 2026-04-19T00:00:00Z
last_edited: 2026-04-19T00:00:00Z
---

# Cavekit Overview

Index of cavekits for the Tiler engine's Smashing-parity widget expansion.

## Domains

| Cavekit | Description | Requirements |
|---|---|---|
| [cavekit-widgets-smashing-parity.md](./cavekit-widgets-smashing-parity.md) | Adds `image`, `meter`, and `comments` widgets to bring Tiler's built-in widget catalog to parity with Smashing. Covers widget classes, partials, engine registration, demo seed wiring, and tests. | R1–R5 (5 requirements) |

## Dependency Graph

This expansion is a single self-contained domain with no external cavekit dependencies. Internal requirement dependencies:

```
R1 (Image)     ──┐
R2 (Meter)     ──┼──> R4 (Engine registration + seed) ──> R5 (Tests)
R3 (Comments)  ──┘
```

- R1, R2, R3 are independent of each other and can be implemented in parallel.
- R4 wires all three into the engine initializer and the `tiler:seed` task; it must run after R1–R3 exist.
- R5 covers tests for all three widgets and their wiring; it depends on R4.

## Coverage Summary

- Cavekits: 1
- Requirements: 5 (R1–R5)
- Acceptance criteria: 41 total
  - R1 (Image widget): 8
  - R2 (Meter widget): 9
  - R3 (Comments widget): 11
  - R4 (Engine registration + seed): 6
  - R5 (Tests): 5

## Implementation Order

Implement in the following order — simplest first, wiring last, tests last:

1. **R1 — Image widget.** Config-only, smallest surface, mirrors existing `text` / `iframe` / `clock` exactly.
2. **R2 — Meter widget.** Data-source-backed, single aggregated value with clamping; reuses `Tiler::Query::Base` aggregation helpers.
3. **R3 — Comments widget.** Data-source-backed multi-row query plus a Stimulus controller for client-side rotation.
4. **R4 — Engine registration, install, seed.** Add the three `require` lines to `lib/tiler/engine.rb` and three new panel rows to the `tiler:seed` task.
5. **R5 — Tests.** Add `test/lib/tiler/widgets/{image,meter,comments}_test.rb`; run `bundle exec rails test` from `/Users/augustingottlieb/tiler/test/dummy`.
