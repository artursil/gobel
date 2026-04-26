# TASKS.md

## Scope

Deliver a minimal playable single game with:
- Board play loop
- Stone pouch and stone draw
- Deck, hand, and playable cards with energy cost
- Poses (passives) for player and opponent
- Money and energy resources
- Full baseline UI layout for one match
- Message board that shows effect text before score changes
- Stone metadata-driven visuals and inspection popups

## Task Board

### P3B - Stone UX and Metadata (Active Now)

- [ ] T-060 Define metadata-rich stone model
  - Assigned: Code Writer
  - Depends on: none
  - References: `content.lua`, `SYSTEMS.md`, `TECH_SPEC.md`
  - Deliverable:
    - Each stone definition contains:
      - `id`
      - `name`
      - `description`
      - `depiction` (short textual motif)
      - `graphic` (current draw key, future sprite path)
      - behavior function reference (pointer) used by resolver
  - Acceptance criteria:
    - Stone behavior is not hardcoded by id checks in resolver
    - Reading one stone definition is enough to understand what it does

- [ ] T-061 Render distinct graphics for each stone type
  - Assigned: Code Writer
  - Depends on: T-060
  - References: `render.lua`, board and stone selector rendering
  - Deliverable:
    - Draw distinct visual marks per stone type on:
      - board stones
      - stone selector chips
      - pouch popup chips
  - Acceptance criteria:
    - Stone types are visually distinguishable without text
    - Graphic key in content controls drawing style

- [ ] T-062 Add click-to-inspect popup for stone selector row
  - Assigned: Code Writer
  - Depends on: T-060, T-061
  - References: `main.lua`, `layout.lua`, `render.lua`
  - Deliverable:
    - Stone selector shows graphics only by default
    - Click stone chip opens popup with selected stone `name` and `description`
  - Acceptance criteria:
    - No name/description always visible in selector row
    - Popup can be opened and closed reliably

- [ ] T-063 Add pouch inventory popup with grid browsing
  - Assigned: Code Writer
  - Depends on: T-060, T-061
  - References: `main.lua`, `layout.lua`, `render.lua`, `pouch.lua`
  - Deliverable:
    - Clicking pouch opens popup with all not-played stones in a graphics-only grid
    - Clicking a stone in popup shows its `name` and `description` in detail area
  - Acceptance criteria:
    - Grid count matches pouch remaining stones
    - Details update on click
    - Popup closes cleanly and returns to match controls

- [ ] T-064 Add popup interaction policy and state guards
  - Assigned: Code Writer
  - Depends on: T-062, T-063
  - References: `main.lua`, input routing
  - Deliverable:
    - Centralized popup state:
      - none
      - selector stone details
      - pouch browser/details
    - Input priority rule: popup consumes clicks before gameplay actions
  - Acceptance criteria:
    - No accidental card/stone/board actions while popup is active
    - Escape or close button behavior is deterministic

### P4 - AI and Opponent Baseline (Deferred)

- [ ] T-040 Integrate opponent baseline with new systems (deferred)
  - Assigned: AI / Simulation Agent
  - Depends on: T-015, T-020
  - References: `ai.lua`, `game.lua`
  - Deliverable:
    - Opponent turn supports stone placement under new state model
    - Optional minimal card usage if defined by spec
  - Acceptance criteria:
    - PvC remains playable end-to-end
    - Opponent actions do not bypass core resolver

### P5 - Testing, Integration, and Quality (Active Now)

- [ ] T-050 Add tests for core systems
  - Assigned: Test Writer
  - Depends on: T-064
  - References: scoring/rules + new systems
  - Deliverable:
    - Tests for money, energy, deck, pouch, action resolution order
    - Tests for stone metadata completeness and behavior hook execution
  - Acceptance criteria:
    - Deterministic pass/fail for representative gameplay scenarios
    - At least one test per critical resource system

- [ ] T-051 Add integration tests for minimal playable loop
  - Assigned: Test Writer
  - Depends on: T-064
  - Deliverable:
    - End-to-end match flow checks:
      - start match
      - draw/play card
      - place stone
      - score updates
      - match conclusion
      - selector popup details flow
      - pouch popup grid/details flow
  - Acceptance criteria:
    - MVP loop is test-covered and repeatable

- [ ] T-052 Integration review and regression pass
  - Assigned: Integrator / Reviewer
  - Depends on: T-050, T-051
  - Deliverable:
    - Verify cross-module compatibility and UI-state consistency
  - Acceptance criteria:
    - No blocked flows in PvP or PvC for MVP scope
    - No rule mismatch against `GAME_RULES.md`, `SYSTEMS.md`, `CONTENT.md`, `TECH_SPEC.md`

- [ ] T-053 Quality and refactor pass
  - Assigned: Code Quality / Refactor
  - Depends on: T-052
  - Deliverable:
    - Improve structure and naming without behavior changes
    - Remove dead code and duplicated logic introduced during MVP delivery
  - Acceptance criteria:
    - No behavior regressions
    - Modules remain small and focused

## Current Priority Order

1. T-060
2. T-061
3. T-062
4. T-063
5. T-064
6. T-050
7. T-051
8. T-052
9. T-053
10. T-040 (deferred)
