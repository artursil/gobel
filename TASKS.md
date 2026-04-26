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

## Task Board

### P0 - Spec Lock (must complete first)

- [ ] T-001 Define MVP turn/state machine
  - Assigned: Content Designer
  - Depends on: none
  - References: `GAME_RULES.md` (turn structure, resources)
  - Deliverable:
    - Create `SYSTEMS.md` with exact match state machine:
      - turn phases and transitions
      - draw timing (cards and stones)
      - action limits
      - end-of-turn/end-of-match conditions
      - effect resolution order
  - Acceptance criteria:
    - No ambiguous timing for draw/play/place/resolve/pass
    - All transitions deterministic

- [ ] T-002 Define MVP content set
  - Assigned: Content Designer
  - Depends on: T-001
  - References: `GAME_RULES.md` (cards, stones, poses, energy, money)
  - Deliverable:
    - Create `CONTENT.md` with minimal playable set:
      - 3-5 card definitions (cost, target, effect)
      - 2-3 stone kinds
      - 3 poses (including run-fixed and run-swappable types)
      - starting deck/pouch/poses for player and opponent
  - Acceptance criteria:
    - Every content item has fully defined behavior and trigger timing
    - No content item requires implementation guesswork

- [ ] T-003 Define technical contracts for systems
  - Assigned: Integrator / Reviewer
  - Depends on: T-001, T-002
  - References: `game.lua`, `render.lua`, `layout.lua`
  - Deliverable:
    - Create `TECH_SPEC.md` with module boundaries and data contracts:
      - state shape for match/player/opponent
      - action payload format
      - message/event queue structure
      - scoring recompute lifecycle
  - Acceptance criteria:
    - Interfaces are explicit enough to code without reinterpretation
    - Existing board/rules/scoring modules can be integrated without rewrite

### P1 - Core Data Structures and Runtime

- [ ] T-010 Implement economy model
  - Assigned: Code Writer
  - Depends on: T-003
  - References: `GAME_RULES.md` (money resource)
  - Deliverable:
    - Add money state and operations (gain/spend/validate)
  - Acceptance criteria:
    - Money cannot go negative
    - All updates flow through a single API

- [ ] T-011 Implement energy model
  - Assigned: Code Writer
  - Depends on: T-003
  - References: `GAME_RULES.md` (energy-limited card play)
  - Deliverable:
    - Add energy state and operations (refresh/spend/check)
  - Acceptance criteria:
    - Card play blocked when energy is insufficient
    - Energy refresh timing follows `SYSTEMS.md`

- [ ] T-012 Implement stone and pouch model
  - Assigned: Code Writer
  - Depends on: T-003
  - References: `stone_queue.lua`, `GAME_RULES.md` (stone pouch)
  - Deliverable:
    - Introduce pouch collection and draw/consume behavior
    - Keep compatibility with board placement flow
  - Acceptance criteria:
    - Stone source for placement is pouch-driven
    - Remaining stones are queryable for UI

- [ ] T-013 Implement card and deck model
  - Assigned: Code Writer
  - Depends on: T-003
  - References: `GAME_RULES.md` (deck and playing cards)
  - Deliverable:
    - Deck/hand/discard with draw and play operations
    - Card effects represented as data + resolver operations
  - Acceptance criteria:
    - Draw and play transitions are deterministic
    - Discard and reshuffle logic matches `SYSTEMS.md`

- [ ] T-014 Implement poses model
  - Assigned: Code Writer
  - Depends on: T-003
  - References: `GAME_RULES.md` (passive effects / poses)
  - Deliverable:
    - Passive pose slots and trigger interface
    - Support run-fixed and run-swappable categories in state
  - Acceptance criteria:
    - Pose effects can modify at least one of score/energy/money/card/stone flows
    - Trigger order follows `SYSTEMS.md`

- [ ] T-015 Implement unified match state
  - Assigned: Code Writer
  - Depends on: T-010, T-011, T-012, T-013, T-014
  - References: `game.lua`, `main.lua`
  - Deliverable:
    - Central match state composed of board + resources + card/stone systems
  - Acceptance criteria:
    - Existing move/pass/finish loop still functions
    - New systems are accessible from renderer and input layer

### P2 - Action Resolution and UX Messaging

- [ ] T-020 Implement action resolver and event queue
  - Assigned: Code Writer
  - Depends on: T-015
  - References: `GAME_RULES.md` (cards before placement)
  - Deliverable:
    - Resolver for actions (play card, place stone, pass)
    - Event queue for staged UI messages and deterministic state updates
  - Acceptance criteria:
    - Every gameplay action produces ordered events
    - Effects are applied in one consistent pipeline

- [ ] T-021 Add message board behavior
  - Assigned: Code Writer
  - Depends on: T-020
  - References: UI target (message before score update)
  - Deliverable:
    - Message board feed + timing control
  - Acceptance criteria:
    - Effect message (example: `+5 mult`) is shown before score box changes
    - Message queue handles chained events without overlap corruption

### P3 - UI Layout and Interaction

- [ ] T-030 Refactor layout regions to target screen map
  - Assigned: Code Writer
  - Depends on: T-015
  - References: `layout.lua`
  - Deliverable:
    - Named layout regions for:
      - player/opponent score boxes
      - center board
      - left and right passive/resource panels
      - bottom pouch/deck/hand/active-stone areas
      - top message board
  - Acceptance criteria:
    - Region coordinates scale with window size
    - No overlap at standard desktop resolution

- [ ] T-031 Render side panels and resource boxes
  - Assigned: Code Writer
  - Depends on: T-030, T-015
  - References: `render.lua`
  - Deliverable:
    - Player: poses (2 columns), energy, money
    - Opponent: poses and energy
  - Acceptance criteria:
    - Values always reflect current state
    - Opponent money is hidden

- [ ] T-032 Render bottom systems (pouch, deck, hand, active stone)
  - Assigned: Code Writer
  - Depends on: T-030, T-013, T-012, T-015
  - References: `render.lua`
  - Deliverable:
    - Bottom-left pouch (remaining stones)
    - Bottom-right deck (remaining cards)
    - Bottom hand (drawn cards)
    - Active stone row above hand
  - Acceptance criteria:
    - Card/stone counts match runtime state
    - Active stone clearly indicates next placeable stone

- [ ] T-033 Add card-play interaction
  - Assigned: Code Writer
  - Depends on: T-032, T-020
  - References: `main.lua`, input routing
  - Deliverable:
    - Input flow to select/play cards from hand
  - Acceptance criteria:
    - Illegal plays are rejected with user-facing message
    - Legal plays consume energy and update hand/discard

### P4 - AI and Opponent Baseline

- [ ] T-040 Integrate opponent baseline with new systems
  - Assigned: AI / Simulation Agent
  - Depends on: T-015, T-020
  - References: `ai.lua`, `game.lua`
  - Deliverable:
    - Opponent turn supports stone placement under new state model
    - Optional minimal card usage if defined by spec
  - Acceptance criteria:
    - PvC remains playable end-to-end
    - Opponent actions do not bypass core resolver

### P5 - Testing, Integration, and Quality

- [ ] T-050 Add tests for core systems
  - Assigned: Test Writer
  - Depends on: T-015, T-020
  - References: scoring/rules + new systems
  - Deliverable:
    - Tests for money, energy, deck, pouch, action resolution order
  - Acceptance criteria:
    - Deterministic pass/fail for representative gameplay scenarios
    - At least one test per critical resource system

- [ ] T-051 Add integration tests for minimal playable loop
  - Assigned: Test Writer
  - Depends on: T-033, T-040
  - Deliverable:
    - End-to-end match flow checks:
      - start match
      - draw/play card
      - place stone
      - score updates
      - match conclusion
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

1. T-001
2. T-002
3. T-003
4. T-010
5. T-011
6. T-012
7. T-013
8. T-014
9. T-015
10. T-020
11. T-021
12. T-030
13. T-031
14. T-032
15. T-033
16. T-040
17. T-050
18. T-051
19. T-052
20. T-053
