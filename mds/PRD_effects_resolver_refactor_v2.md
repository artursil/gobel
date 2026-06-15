# PRD: Effects & Resolver Refactor (action/phase pipeline)

**Status:** ready-for-agent  
**Source:** Grill-with-docs session 2026-06-15  
**Supersedes:** Issue #27 / prior stone-effects PRD where decisions conflict (notably `board_reconcile`, defence full-board recompute, `macro`/`sub`/`when` vocabulary)  
**Triage label:** `ready-for-agent`  
**Canonical glossary:** `CONTEXT.md`  
**Normative detail:** `docs/effects-architecture.md`, ADR 0001 (to be updated)

---

## Problem Statement

Adding new stones made `single_game/resolver` unreadable: many overlapping modules (`stone_removal` vs `remove_stones`, `board_reconcile`, `effect_tick_lifecycle`, `placement_lifecycle`, `anti_capture_immunity`, etc.) with unclear ownership. The resolver directory no longer answers “what happens when I play a stone?” in one place.

Effects scheduling uses three overlapping vocabularies (`macro`, `sub`, `when`, `lifecycle`) while `sub` adds no meaning beyond `phase`. New stone implementations skipped declarative **conditions** and inlined gating in helpers. Removal effects use hidden board watchers (metatable hooks) instead of explicit pipeline steps. Defence stone and other cross-stone buffs are over-engineered with full-board reconcile passes when the intended behavior is simpler.

Developers cannot trace stone behavior from definitions alone, and agents reintroduce stone-specific branches in the resolver on every new stone PR.

## Solution

Refactor to a single scheduling model and a readable resolver layout:

- Every effect declares **`action`** + **`phase`** (+ optional **`conditions`**); factories expose **`apply` only**
- **`resolve_round`** orchestrates scoring beats; **`on_play` pipeline** lives in resolver stages; top-level **`resolver`** is a thin action API
- Generic **stages** handle board hygiene (remove stones, tick timers, legality, dispatch removal); **effects** handle scoring and cell setup
- **Sacrifice** (kamikaze) is not **removal** for `on_removed` purposes
- **Defence** applies a one-time solidity buff on play; adjacent placements pick up buffs via **shared stone effects**
- **Anti-capture**: effect sets/ticks immunity; **stages helper** checks immunity during legality
- Drop **`board_reconcile`** as an action; drop **`sub`** entirely

Deliver in phased PRs so reviews stay small and visual regression specs stay frozen.

## User Stories

### Scheduling vocabulary

1. As a **Code Writer**, I want a single `action` field on every effect definition, so that I never choose between `macro`, `when`, or `lifecycle`.
2. As a **Code Writer**, I want a single `phase` field (`territory`, `points`, `mult`), so that `sub` is not a duplicate axis.
3. As a **Code Writer**, I want `action` and `phase` defined as enums in one module, so that schema validation and the resolver share the same vocabulary.
4. As a **Code Writer**, I want stone placement scheduled as `action = on_play`, so that naming matches player intent (“when I play a stone”).
5. As a **Code Writer**, I want card plays scheduled as `action = on_card`, so that stones and cards use parallel naming.
6. As a **reviewer**, I want legacy `macro`/`sub`/`when` accepted only during migration with schema warnings, so that old defs do not break mid-refactor.
7. As a **reviewer**, I want `board_reconcile` removed from the action enum, so that agents do not add full-board reconcile runners for stones that only need `on_play`.

### Resolver readability

8. As a **Code Writer**, I want `resolve_round` to read as a step-by-step script for each scoring action, so that I can follow territory → points → mult without spelunking.
9. As a **Code Writer**, I want the on-play pipeline (commit → remove stones → phases → legality) in a dedicated stage module, so that `resolver` stays a thin submit/validate/event API.
10. As a **Code Writer**, I want resolver files grouped into `stages`, `stages_helpers`, and `helpers`, so that directory layout matches responsibility.
11. As a **Code Writer**, I want `remove_stones` and `dispatch_removed` as separate stages with distinct names, so that board hygiene and removal-effect beats are not confused.
12. As a **developer**, I want orphan resolver modules from the stones PR deleted after migration, so that duplicate paths do not linger.

### Removal and sacrifice

13. As a **Code Writer**, I want removal effects dispatched only when the code that removed a stone explicitly requests it, so that there is no hidden board metatable watching.
14. As a **Code Writer**, I want every removal path (capture, timer expiry, card damage, etc.) to call the removal-dispatch stage, so that `on_removed` effects never silently miss.
15. As a **Code Writer**, I want kamikaze self-removal to skip `on_removed` effects, so that sacrifice is not treated as capture-style removal.
16. As a **Code Writer**, I want kamikaze to still score via placement record in the points phase after self-removal, so that sacrifice payout is unchanged.

### Tick and timers

17. As a **Code Writer**, I want one generic end-of-turn tick stage that subtracts 1 from all timer fields on the board, so that the resolver does not know what each timer means.
18. As a **Code Writer**, I want expired stones removed in the remove-stones stage after tick, so that expiry is board hygiene not effect hook logic.
19. As a **Code Writer**, I want timer side effects (immunity decay, blockade shrink) to run via effects with `action = tick`, so that meaning stays in helper effects.

### Conditions

20. As a **Code Writer**, I want optional `conditions` on every effect definition (stone, card, stance), so that gating is declarative.
21. As a **Code Writer**, I want the effect runner to call `conditions.eval_all` immediately before every `apply`, so that helpers do not hide `if` gates.
22. As a **Code Writer**, I want copper-threshold and similar stone gates migrated to condition definitions, so that stone defs document their requirements.
23. As a **Code Writer**, I want one condition module under `objects`, so that resolver `Condition` duplicate is deleted.

### Defence and shared stone effects

24. As a **Code Writer**, I want defence stone to add solidity once on `on_play` to itself and connected friendly stones, so that the buff is permanent.
25. As a **Code Writer**, I want no defence recalculation when stones are later captured, so that simplicity matches design intent.
26. As a **Code Writer**, I want a new stone placed adjacent to an existing defence stone to receive the defence buff via shared stone effects, so that cross-stone buffs are declared once.
27. As a **Code Writer**, I want shared stone effects to hold pattern mult and defence-adjacency definitions, so that individual stone defs are not copy-pasted.

### Anti-capture and legality

28. As a **Code Writer**, I want anti-capture `on_play` effect to set `immunity_remaining` on the cell, so that immunity is cell-owned state.
29. As a **Code Writer**, I want anti-capture `tick` effect to decrement immunity, so that duration is effect-driven.
30. As a **Code Writer**, I want a stages helper that answers “can this capture happen?” from `immunity_remaining`, so that legality does not duplicate effect logic.
31. As a **Code Writer**, I want the legality-of-moves stage to use that helper when filtering captures, so that players experience “I can’t capture that group” consistently.
32. As a **developer**, I want the resolver anti-capture module deleted after migration, so that immunity is not split across two homes.

### Effects layer

33. As a **Code Writer**, I want effect factories to delegate to helper effects with `apply` only, so that hooks like `on_placement` and `on_tick` on factories are gone.
34. As a **Code Writer**, I want placement-record effects to run from `round_stone_effects` for the current play, so that kamikaze scoring works after self-removal.
35. As a **Code Writer**, I want board-scan effects to skip placement-record effect names, so that on-play points are not double-applied.
36. As a **Code Writer**, I want attack/heal card effects to stop invoking a board-reconcile runner, so that card damage does not trigger obsolete full-board passes.

### AI and previews

37. As a **Code Writer**, I want AI placement scoring to use the same `action`/`phase` and placement-record rules as the resolver, so that bot heuristics do not drift.
38. As a **Code Writer**, I want placement preview resolution moved to the objects layer, so that resolver placement-lifecycle modules are not duplicated for AI.

### Documentation

39. As a **reviewer**, I want `CONTEXT.md` to remain a glossary only, so that domain terms stay separate from implementation.
40. As a **reviewer**, I want ADR 0001 and `effects-architecture.md` updated to match grill decisions, so that future PRs have one normative source.
41. As an **agent**, I want a phased PR breakdown in this PRD, so that implementation can land incrementally without a mega-diff.

### Tests and regression

42. As a **reviewer**, I want visual stone scoring specs treated as frozen scenarios, so that only assert values change when behavior genuinely shifts.
43. As a **Code Writer**, I want unit tests on each stage module with seeded boards, so that pipeline steps are verified in isolation.
44. As a **Code Writer**, I want integration tests through `resolver.submit_action` for end-to-end on-play flows, so that the highest seam catches wiring mistakes.
45. As a **Code Writer**, I want condition + stone combo unit tests, so that declarative gating is regression-safe.

## Implementation Decisions

### Action and phase enums (prototype decision shape)

Single source of truth for scheduling vocabulary:

```
ACTION = {
  game_start, before_turn, on_card, on_play,
  end_of_turn, tick, on_removed, game_end
}

PHASE = { territory, points, mult }

PHASE_ORDER = { territory, points, mult }
```

Effect definitions use `action` + `phase`. Legacy `macro`/`sub`/`when`/`lifecycle` map to these during migration then are rejected by schema.

`sub` is deleted — it was always identical to `phase`.

`board_reconcile` is deleted as an action. No full-board reconcile runner.

### On-play pipeline (fixed order)

After a stone is committed to the board:

1. Commit board
2. Remove stones stage — captures, sacrifice self-removal (kamikaze), timed expiry; capture points
3. Dispatch removed stage — `on_removed` effects for stones that left (explicit call; kamikaze sacrifice excluded)
4. Scoring resolve — `action = on_play`, phases in order: territory → points → mult (placement record for current play)
5. Legality of moves stage — refresh cached legal placements

Top-level resolver only enqueues events and calls this pipeline; it does not embed stone-specific branches.

### resolve_round responsibilities

- Hydrate score baselines from player state
- For a given `action`, run `PHASE_ORDER` and invoke the effect manager per phase
- Territory phase may delegate to a stages helper for distance → assignment → value → count substeps
- On `end_of_turn`: run tick stage, remove expired stones, run `action = tick` effects, tick stances/card memory/territory control as today
- Sync player scores back after resolve

### Stage vs effect ownership

| Concern | Owner |
|---------|--------|
| Capture, sacrifice removal, expiry removal | Remove stones stage |
| Explicit `on_removed` effect dispatch | Dispatch removed stage |
| Subtract 1 from timer fields (all objects) | Tick objects stage |
| Whether an intersection is playable / capturable | Legality stage + stages helpers |
| Points, mult, territory scoring, cell setup | Effect `apply` in matching phase |
| Immunity set on play, immunity decay | Anti-capture helper effect (`on_play`, `tick`) |
| Immunity blocks capture | Stages helper used by legality stage |

Stages must not accumulate `if stone_id ==` branches; stone rules come from defs, tags, and metadata.

### Removal effects dispatch

- Delete board metatable hooks that auto-fire on cell clear
- Every mutation path that removes stones calls dispatch removed with old board and new board
- Sacrifice flag on remove-stones step excludes those cells from dispatch removed

### Defence stone behavior

- `on_play`: one-time solidity bonus to defence stone and connected friendly stones at placement time
- Buff is permanent — no update when stones are later captured or removed
- New stone placed adjacent to existing defence stone receives buff via entry in shared stone effects (not a board reconcile pass)
- Attack/heal cards that change solidity do not trigger a reconcile runner; they mutate cell solidity directly

### Anti-capture

- `on_play` effect writes `immunity_remaining` on cell
- `tick` effect decrements `immunity_remaining`
- Stages helper exposes whether a proposed capture is blocked by immunity
- Legality stage consults helper when building legal moves

### Conditions

- All object types may declare `conditions: [{ condition_name, ... }]`
- Effect manager evaluates all conditions before `apply`; failed conditions skip the effect
- Consolidate to one condition registry under objects; delete duplicate resolver condition module

### Directory layout (conceptual)

- **resolve_round** — scoring beat orchestrator
- **stages** — on_play_pipeline, remove_stones, legality_of_moves, tick_objects, dispatch_removed
- **stages_helpers** — anti_capture legality check, territory pass substeps
- **helpers** — state queries, placement record, territory control rounds, blocked cells, card play memory
- **objects** — effect enums, schedule, conditions, factories, helper effects, shared stone effects

Modules to delete after migration: board reconcile runner, effect tick lifecycle, resolver anti-capture module, placement lifecycle, placement effects wrapper, resolved type registry (if apply-only payloads suffice), stone removal hooks module, redundant phase re-export module, separate board cell timer modules absorbed into tick stage.

### Phased delivery

1. Enums and rename (`action`, `on_play`, `on_card`; drop `sub`) — behavior-neutral
2. Resolver restructure — extract on-play pipeline; thin resolver API
3. Removal and tick — dispatch removed, tick objects; delete hooks and tick lifecycle modules
4. Effects absorb stone logic — defence one-shot, shared stone effects adjacency, delete reconcile and placement lifecycle
5. Conditions on stones — eval_all everywhere; migrate imperative gates
6. Anti-capture and legality — stages helper + delete resolver anti-capture module
7. Docs and cleanup — update ADR and architecture doc; delete dead modules; full spec run

## Testing Decisions

### What makes a good test

- Assert **external behavior** (board state, scores, legality, prisoners, messages) — not which internal module ran
- Prefer the **highest seam** that still gives deterministic, fast feedback
- Visual specs: **frozen boards and placement sequences**; change assertions only when product behavior intentionally changed
- Stage unit tests: seed a minimal `state` table and assert outcomes of one pipeline step — acceptable because stages are the public contract between resolver and board

### Testing seams (proposed)

| Seam | What it verifies | Prior art |
|------|------------------|-----------|
| **Integration: `resolver.submit_action`** | Full on-play, on-card, end-of-turn flows; scores, board, legality, messages | `spec/integration/resolver_spec.lua`, `spec/integration/card_ui_flow_spec.lua` |
| **Visual stone scoring specs** | Per-stone regression scenarios; state flags and scores only | `spec/visual/stones_scoring/*` (frozen scenarios) |
| **Unit: stage modules** | remove_stones, dispatch_removed, tick_objects, legality with seeded boards | `spec/unit/placement_runner_spec.lua` |
| **Unit: effect schema + schedule** | Valid `action`/`phase`; legacy mapping during migration | `spec/unit/effect_schema_spec.lua`, `spec/unit/stone_resolve_spec.lua` |
| **Unit: conditions** | Declarative gates before apply | `spec/unit/conditions_spec.lua` |
| **Unit: stages helper anti-capture** | Capture blocked when `immunity_remaining > 0` | New; pattern from `spec/visual/stones_scoring/16_anti_capture_stone_spec.lua` assertions |
| **Unit: defence + shared effects** | One-shot buff on play; adjacent placement buff | Extend `spec/visual/stones_scoring/14_defence_stone_spec.lua` assert values if behavior changes |

New seams should be added at the **stage** level only when integration tests are too heavy; do not add tests that assert internal `require` graph or file layout.

## Out of Scope

- New stone designs or balance changes (parameters unchanged unless assert fixes require it)
- Rewriting visual spec boards, hands, or placement sequences
- AI MCTS / search latency tuning
- UI/render changes except messages already asserted in specs
- Card UI refactor (separate PRD)
- Implementing stone effects not yet on definitions (parallel issues #3–#36 remain separate vertical slices after infrastructure lands)

## Further Notes

- This PRD **supersedes** grill-inconsistent items in issue #27 (e.g. `board_reconcile` for defence, `macro`/`sub` vocabulary, hook-based lifecycle taxonomy).
- `CONTEXT.md` at repo root already reflects glossary decisions from the grill session.
- ADR 0001 and `docs/effects-architecture.md` must be updated in the final cleanup PR to avoid drift.
- Confirm testing seams with implementer before adding new stage-only specs that duplicate visual coverage.
