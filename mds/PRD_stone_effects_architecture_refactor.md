# PRD: Stone Effects Architecture Refactor

**Status:** ready-for-agent  
**Source:** Grill-me architecture session on stones implementation branch vs `main`  
**Triage label:** `ready-for-agent`  
**Canonical doc:** `docs/effects-architecture.md`  
**Scope:** Refactor stone effect implementation and resolver orchestration to match agreed architecture. Correct state modeling, navigation, and test hygiene on the current branch. Does not add new stone designs or rebalance parameters.

---

## Problem Statement

The stones implementation branch introduced broad resolver and effect changes that violate the project's effects-driven architecture. Stone behavior is split across empty effect stubs, orphan resolver hooks, and new modules under the resolve pipeline that are not reachable from stone definitions. Runtime state (timers, stored values, immunity) uses parallel coordinate-keyed side maps requiring global cleanup instead of living on board cells. Placement-only shape effects were added to shared effect tables and board-scan paths. Energy remains buried in resource bags rather than first-class player state. AI placement scoring duplicates resolver type mapping with fragile conditional chains.

Visual scoring specs were rewritten with different boards, hands, and placement sequences — violating the rule that specs are frozen scenarios and may only receive assert-value fixes. This makes regression signal unreliable and blocks confident merges.

Developers and agents cannot answer "what does this stone do?" by reading its definition and following one entry point. The same class of drift will recur without a normative architecture document and a structured refactor.

## Solution

Refactor the branch to the architecture in `docs/effects-architecture.md`:

- Stone def → `effect_name` → effect factory → helper effect → state mutation
- Resolver schedules lifecycle runners only; no stone-specific gameplay branches
- Runtime stone state on board cells; energy on player; blockade as board-zone exception
- Placement-only shape effects inline on stone defs; defence via board-reconcile `apply`
- One `effect_name` with multiple hooks for multi-lifecycle stones
- Manual audit of visual specs vs baseline; revert scenario drift
- Phased execution: tests → state model → infrastructure → stone migration → hygiene

## User Stories

### Navigation and architecture

1. As a **Code Writer**, I want every stone `effect_name` to resolve through a factory that delegates to a helper effect, so that I can trace behavior from the stone definition in one path.
2. As a **Code Writer**, I want the resolver to invoke generic lifecycle runners, so that I do not add `if effect_name ==` branches when implementing new stones.
3. As a **reviewer**, I want empty effect stubs and orphan resolver hooks removed, so that stone definitions truthfully describe what runs.
4. As a **reviewer**, I want `docs/effects-architecture.md` as the normative reference, so that future PRs can be checked against a single checklist.
5. As an **AI planner**, I want implementation briefs to reference lifecycle taxonomy, so that agents do not reintroduce board-scan placement effects.

### State model

6. As a **Code Writer**, I want `player.energy` and `player.energy_max` as first-class fields, so that `add_energy` mirrors `add_points` mutator patterns.
7. As a **Code Writer**, I want delay-reward timers stored on board cells, so that stone removal implicitly clears timer state without global sweeps.
8. As a **Code Writer**, I want escalating stored values on `cell.stored_value` only, so that parallel `stone_stored_values` bags are eliminated.
9. As a **Code Writer**, I want anti-capture immunity as `cell.immunity_remaining`, so that immunity does not require coordinate side maps.
10. As a **Code Writer**, I want tick passes to scan the board for cells with timer/immunity fields, so that no separate timer registry is maintained.
11. As a **Code Writer**, I want blockade to remain a board-zone map on empty cells, so that the one non-cell exception is explicit and documented.

### Lifecycle and effects

12. As a **Code Writer**, I want `wall_stone`, `diagonal_group_points`, and `line_group_points` declared inline on their stone defs with `lifecycle = placement`, so that they never run during board scan.
13. As a **Code Writer**, I want shared reusable effect tables to contain only board-scan effects (e.g. pattern mult), so that placement-only shapes are not shared templates.
14. As a **Code Writer**, I want `defence_solidity_network` to use a single `apply(state)` under `board_reconcile`, so that solidity updates read the full board after any topology change.
15. As a **Code Writer**, I want `delay_reward_survival` to use one `effect_name` with `on_placement` and `on_tick` hooks, so that the stone def stays one line.
16. As a **Code Writer**, I want `escalating_money_stone` capture penalty under `lifecycle = on_removed`, so that removal gameplay is visible on the stone def.
17. As a **Code Writer**, I want kamikaze legality in rules and payout/removal in effects, so that rules vs scoring boundaries stay clear.

### Code organization

18. As a **Code Writer**, I want state-mutating stone logic in helper effect modules, so that the effect registry stays a thin factory layer.
19. As a **Code Writer**, I want pure utilities in effect helpers only, so that non-factory functions are not added to the registry module.
20. As a **Code Writer**, I want stone-specific modules moved out of the resolve pipeline into helper effects, so that resolve modules orchestrate timing not gameplay.
21. As a **Code Writer**, I want a shared resolved-type-to-round-def registry used by resolver and AI placement scoring, so that `if/elseif` chains are not duplicated.

### Tests

22. As a **reviewer**, I want visual scoring specs manually audited against baseline, so that changed boards/hands/placements are reverted.
23. As a **reviewer**, I want assert-only fixes preserved where behavior genuinely changed, so that correct implementation updates are not lost.
24. As a **Code Writer**, I want unit tests on effect factories and helper effects at the highest practical seam, so that behavior is verified without pixel tests.
25. As a **Code Writer**, I want integration tests for one end-to-end resolve flow per migrated stone cluster, so that lifecycle scheduling is exercised.
26. As a **author**, I want agents forbidden from rewriting visual scenario setup during stone implementation, so that the regression contract holds.

### Migration and delivery

27. As a **reviewer**, I want refactor delivered in phased PRs (tests, state, infrastructure, stones, hygiene), so that reviews stay small.
28. As a **Code Writer**, I want simple placement stones migrated before complex enclosure/capture stones, so that infrastructure is proven early.
29. As a **developer**, I want dead resolver stone modules deleted after migration, so that duplicate paths do not linger.
30. As a **developer**, I want docstrings added on all new or changed factories and helpers, so that API contracts are explicit.

### Stone coverage (migration acceptance)

31. As a **Code Writer**, I want `points_stone`, `energy_stone`, `wall`, `diagonal_stone`, and `line_stone` migrated in the first stone batch, so that placement-only and simple mutators work end-to-end.
32. As a **Code Writer**, I want `defence_stone` migrated with board-reconcile solidity, so that the empty-stub anti-pattern is eliminated.
33. As a **Code Writer**, I want `delay_reward_stone`, `blockade_stone`, and `anti_capture_stone` migrated with cell-owned tick state, so that side maps are gone for those features.
34. As a **Code Writer**, I want `escalating_money_stone` migrated with `on_removed` penalty, so that capture punishment is stone-declared.
35. As a **Code Writer**, I want `capture_stone` and `kamikaze_stone` migrated with effects-driven payout and removal, so that combat stones match architecture before territory/economy cluster.

## Implementation Decisions

### Architecture

- Adopt the normative model in `docs/effects-architecture.md` as the binding design for this refactor.
- Effect factories register `effect_name` → resolved effect with lifecycle hooks; factories delegate to helper effects; factories do not contain gameplay logic beyond wiring.
- Resolver exposes generic runners: placement, board scan, board reconcile, tick, on removed. Runners resolve effects from stone defs (or board event context for on_removed) and invoke the appropriate hook.
- Multi-lifecycle stones use one `effect_name` and multiple hooks on the resolved effect object. Factory docstrings list all hooks.

### Lifecycle metadata

Effect definitions carry `lifecycle` (or equivalent validated field):

```
placement | board_scan | board_reconcile | tick | on_removed
```

Scoring macro/sub (`playing_stones`, `territory`, `points`, `mult`) remains for board-scan and scoring-phase matching. Placement-only effects skip board scan entirely via lifecycle, not in-apply guards.

### State shapes

**Player energy** (prototype decision shape):

```
player.energy: number
player.energy_max: number
```

Energy mutator module operates on these fields. `add_energy` effect uses the same owner→player resolution as points effects.

**Board cell runtime** (fields set by effects on placement or tick; absent when not needed):

```
cell.survival_rounds_remaining: integer | nil
cell.delay_payout: number | nil
cell.stored_value: number | nil
cell.immunity_remaining: integer | nil
cell.placed_via_play: boolean | nil
cell.placed_turn_number: integer | nil
cell.solidity: number
cell._defence_solidity_bonus: number | nil  -- until renamed during hygiene
```

Remove coordinate-keyed bags: `board_cell_timers`, `stone_stored_values` (bag layer), immunity side maps. Tick scans occupied cells.

**Board-zone exception:**

```
state.blocked_cells: map<cell_key, rounds_remaining>
```

Maintained by blockade helper; not copied onto stone instances.

### Placement-only shape effects

- Remove `wall_stone`, `diagonal_group_points`, `line_group_points` from shared reusable effect tables used for board scan.
- Declare inline on `wall`, `diagonal_stone`, `line_stone` definitions with `lifecycle = placement`.
- Shared tables retain only effects that participate in board scan (pattern mult family).

### Defence solidity

- `defence_solidity_network` helper implements `apply(state)` that recomputes solidity from current board connectivity.
- Registered as `lifecycle = board_reconcile`.
- Delete resolver-only recompute calls that bypass the effect path.

### Removal

- Cell-owned state needs no global cleanup on removal.
- `on_removed` hooks only for cross-player consequences (escalating money capture penalty).
- Generic board-diff runner handles commit ordering and board-zone hygiene only — no `if kind ==` gameplay.

### Module boundaries

- **Effect registry:** factories and resolve entry points only.
- **Helper effects:** one module per `effect_name` or tightly related family; state mutation allowed.
- **Effect helpers:** pure functions shared across helpers.
- **Resolve pipeline:** lifecycle scheduling, territory pipeline, legality, effect manager — no stone-specific gameplay modules after migration.

### AI mirror

- Extract shared map from resolved effect type to round effect definition shape.
- AI placement scoring reads the same registry; no parallel conditional chain on types.

### Execution phases

1. **Tests** — manual per-file audit of visual specs vs baseline; revert scenario drift; keep assert-only fixes.
2. **State model** — player energy; cell runtime fields; remove side maps; blockade map retained.
3. **Infrastructure** — lifecycle runners; helper effect directory layout; shared AI/resolver registry; delete stubs/orphans.
4. **Stone migration** — batch order: simple placement → defence reconcile → tick stones → on_removed → capture/kamikaze → remaining territory/economy cluster.
5. **Hygiene** — docstrings; delete dead modules; run unit, integration, and visual suites.

### Rules vs effects

- Placement legality exceptions (e.g. kamikaze suicide override) remain in rules validation.
- Payout, removal, timers, immunity, and board mutations remain in effects/helpers.

## Testing Decisions

### Principles

- Test **external behavior** visible in game state and resolver outputs — not private helper internals or file layout.
- Prefer **existing seams** at the highest level that still gives fast signal: visual scoring specs for end-to-end stone scenarios; unit tests for factories and pure helpers; integration tests for resolve-round passes.
- Do not add pixel or animation assertions for this refactor.

### Modules exercised

| Seam | What it validates | Prior art |
|------|-------------------|-----------|
| Visual stones scoring specs | Given board/hand/placement → scores, energy, solidity, money, legality | Existing `spec/visual/stones_scoring/*` |
| Unit: effect factories | Resolved effect shape, lifecycle metadata, hook presence | `spec/unit/effects_spec.lua`, `spec/unit/effects_wall_spec.lua` |
| Unit: helper effects | Isolated state mutation given seeded board/player | Extend effects unit specs |
| Unit: energy mutator | Gain/spend/clamp on `player.energy` | `spec/unit/energy_spec.lua` |
| Integration: resolve round | Placement → scoring macro/sub → state fields | `spec/integration/*`, `spec/unit/resolve_scoring_macro_spec.lua` |
| Unit: scoring phases | Placement-only names excluded from board scan | `spec/unit/resolve_scoring_macro_spec.lua` |

### Test hygiene (binding)

- Visual spec **scenarios** (boards, hands, placement sequences) must match baseline unless a documented product change explicitly updates the entry doc first.
- Implementation PRs may only change **assertions** and non-scenario structure (formatting) where scenarios are identical.
- After refactor batches, run affected `spec/unit/*`, `spec/integration/*`, and touched visual specs.

### New seams (minimal)

- **Lifecycle runner integration:** one integration example per lifecycle kind (placement, board_reconcile, tick, on_removed) proving generic runner invokes the correct hook without stone-specific resolver branches.
- **Registry parity:** unit test that AI placement type map keys match resolver registry keys for immediate placement effects.

## Out of Scope

- New stone designs or changes to `mds/STONES_IMPLEMENTATION_ENTRY.md` behavior text.
- Parameter rebalancing unless required to fix a broken test assert after scenario revert.
- Animation definitions and UI feedback changes.
- AI MCTS/heuristic tuning beyond shared placement-effect registry alignment.
- Card effect architecture refactor (stones only in this PRD).
- Rewriting the curated x/plus/wall visual spec file beyond assert fixes if scenarios unchanged.
- Performance optimization of full-board tick scans (document as acceptable unless profiling proves otherwise).

## Further Notes

- **Canonical architecture:** `docs/effects-architecture.md` — link from `docs/README.md`.
- **Checklist:** Section 11 of the architecture doc is the reviewer gate for each stone migration PR.
- **Branch context:** Work applies to the current stones implementation branch diff vs `main`; do not restart from zero unless a phase proves unmergeable.
- **Issue tracker:** Publish as GitHub issue with label `ready-for-agent`; this file is canonical in repo until implementation issues are split via `to-issues` if needed.
