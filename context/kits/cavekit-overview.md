---
created: 2026-04-19T00:00:00Z
last_edited: 2026-04-22T00:00:00Z
---

# Cavekit Overview

Index of cavekits for the Tiler engine's Smashing-parity widget expansion and follow-on dashboard hardening.

## Domains

| Cavekit | Description | Requirements |
|---|---|---|
| [cavekit-widgets-smashing-parity.md](./cavekit-widgets-smashing-parity.md) | Adds `image`, `meter`, and `comments` widgets to bring Tiler's built-in widget catalog to parity with Smashing. Covers widget classes, partials, engine registration, demo seed wiring, and tests. | R1–R10 (10 requirements) |
| [cavekit-dashboard-layout.md](./cavekit-dashboard-layout.md) | Locks down dashboard grid layout/CSS, layout-PATCH input validation, an opt-in scroll allowlist, a no-overflow regression smoke test, dummy-app migration handling, and a turbo-frame eager-load test mode. Codifies fixes for `/ck:check` rounds 2-3 findings. | R1–R6 (6 requirements) |
| [cavekit-widget-palette-drag-drop.md](./cavekit-widget-palette-drag-drop.md) | Drag-from-palette feature: sidebar widget palette in edit mode, `default_config` / `default_size` on every widget, drop-on-grid creates a panel via the existing endpoint, cancel-mid-drag, server-side widget_type validation, and end-to-end system coverage. | R1–R7 (7 requirements) |

## Dependency Graph

```
cavekit-widgets-smashing-parity
        │
        │  R7 (URL allowlist), R8 (enum whitelist), R9 (required-key states)
        ▼
cavekit-widget-palette-drag-drop ◀──── R3 (layout PATCH validation) ──── cavekit-dashboard-layout
```

- `cavekit-widgets-smashing-parity` is the foundational widget kit; the other two reference it.
- `cavekit-dashboard-layout` is independent of the widget catalog (R1–R6 are about CSS/PATCH/test-infra), but the palette kit depends on its R3 to validate drop-supplied coords.
- `cavekit-widget-palette-drag-drop` depends on both other kits — on widgets-smashing-parity for default-config conformance, and on dashboard-layout R3 for coord validation on drop.

Internal requirement dependencies within `cavekit-widgets-smashing-parity` (unchanged):

```
R1 (Image)     ──┐
R2 (Meter)     ──┼──> R4 (Engine registration + seed) ──> R5 (Tests)
R3 (Comments)  ──┘
```

Internal requirement dependencies within `cavekit-dashboard-layout`:

```
R1 (Panel chrome) ──> R2 (Scroll allowlist) ──┐
                                              ├──> R4 (Overflow smoke test)
R6 (Eager-load test mode) ────────────────────┘
R3 (PATCH validation), R5 (Dummy migrations) — independent
```

Internal requirement dependencies within `cavekit-widget-palette-drag-drop`:

```
R1 (Palette UI) ──┐
R2 (Defaults)  ──┼──> R3 (Drop creates panel) ──> R4 (Cancel mid-drag) ──┐
                 │                                                       ├──> R7 (System tests)
R5 (Server validates widget_type) ─────────────────────────────────────  │
R6 (Defaults respect security kits) ─── depends on R2 ──────────────────┘
```

## Coverage Summary

- Cavekits: 3
- Requirements: 23 (10 + 6 + 7)
- Acceptance criteria by kit:
  - `cavekit-widgets-smashing-parity` — R1–R10 (see kit for per-requirement counts)
  - `cavekit-dashboard-layout` — R1 (4) + R2 (4) + R3 (6) + R4 (4) + R5 (4) + R6 (4) = 26
  - `cavekit-widget-palette-drag-drop` — R1 (5) + R2 (4) + R3 (5) + R4 (2) + R5 (3) + R6 (3) + R7 (5) = 27

## Implementation Order

Implement in the following order — foundational widget catalog first, then layout/test-infra hardening, then the palette feature on top:

1. **`cavekit-widgets-smashing-parity` R1–R5** — Image, Meter, Comments widgets and their wiring/tests (original sequence: image → meter → comments → engine wiring → tests).
2. **`cavekit-widgets-smashing-parity` R6–R10** — security/validation/visibility additions referenced by the palette kit.
3. **`cavekit-dashboard-layout` R5, R6** — fix the test infra (dummy migrations, eager-load) so the rest of the kit's tests can run reliably.
4. **`cavekit-dashboard-layout` R1, R2, R3** — CSS chrome, scroll allowlist, PATCH validation. Codify before the palette ships so drops land on a stable substrate.
5. **`cavekit-dashboard-layout` R4** — overflow smoke test depends on R1+R2+R6.
6. **`cavekit-widget-palette-drag-drop` R2** — `default_config` / `default_size` on every widget (foundational for the drop flow).
7. **`cavekit-widget-palette-drag-drop` R5** — server widget_type validation (cheap, prevents regressions before the UI ships).
8. **`cavekit-widget-palette-drag-drop` R1, R3** — palette UI surface and drop-creates-panel flow.
9. **`cavekit-widget-palette-drag-drop` R4, R6** — cancel-mid-drag and security/validation kit conformance for defaults.
10. **`cavekit-widget-palette-drag-drop` R7** — full end-to-end system test coverage.
