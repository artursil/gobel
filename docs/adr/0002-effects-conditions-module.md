# ADR 0002: Effects–conditions module layout and kwargs contract

**Status:** accepted (amended 2026-06-18)  
**Date:** 2026-06-17  
**Issue:** GitHub #42 (Phase 5)  
**Related:** [ADR 0003](0003-pending-stone-removals-and-removal-beat.md)

## Context

Effect and condition logic previously lived across top-level `objects` shims (`effects`, `conditions`, `effects_helpers`, `helper_effects`, `effect_enums`, `effect_schedule`, `effect_factory`) and a duplicate resolver schema (`single_game/resolver/Effect.lua`). Phases 0–4 migrated behavior into `objects/effects_conditions/`; Phase 5 removes compatibility shims.

A follow-up grill session (2026-06-18) locked per-file layout, inline `apply`, removal queue integration, and elimination of `on_tick`.

## Decision

### Module layout

```
objects/effects_conditions/
  EffectSchema.lua      # load-time validation only (does NOT build runtime instances)
  ConditionSchema.lua   # condition row validation
  scheduling.lua        # ACTION/PHASE enums, schedule parsing
  effects.lua           # thin registry: effect_name → effects/<name>.build
  conditions.lua        # thin registry: condition_name → conditions/<name>.eval
  run.lua               # sole resolver entry: eval conditions → merge kwargs → apply
  effects/
    <effect_name>.lua   # module docstring + build(effect) → inline apply
  conditions/
    <condition_name>.lua
  helpers/
    shared/             # reusable math, pending_removals enqueue, capture supplemental pick, …
```

Delete or stop using: monolithic inlined builders in `effects.lua`, `helpers/effects/` per-effect trees, `EffectSchema.build` as factory, `kwargs_from_def`, resolved `on_tick` hooks.

Top-level shims (`objects/effects.lua`, `objects/conditions.lua`, …) and resolver `Effect.lua` are deleted. Callers require `objects.effects_conditions.*` directly.

### Builder output (resolved effect)

Each `effects/<name>.lua` exports **`build(effect)`** returning a plain table:

- `type`, `action`, `phase`, `priority`, `value`, `conditions`, …
- **`apply = function(state, owner, kwargs)`** — inline closure; not `M.apply`

**Forbidden** on resolved instances: `on_tick`, `kwargs_from_def`, `macro`, `sub`, `accepts_kwargs`, `_effect_def`.

Def fields (`rounds`, `duration`, `payout`, …) are read from the `effect` argument inside `build` and closed over by `apply` — not injected into kwargs.

### Kwargs contract

1. **Effect apply:** `apply(state, owner, kwargs)` — always three arguments.
2. **Condition eval:** `eval(state, owner, condition_def?) → pass: boolean, fragment: table | nil`.
3. **Runner merge:** All conditions on an effect must pass; non-nil fragments merge into one `kwargs` table before `apply`.
4. **Required keys:** `require_kwargs` when conditions supply computed values (e.g. `{ blocks }`, `{ row, col }`).
5. **Resolution context:** Selected board targets, placement coords, and tick cell context are read inside **`helpers/shared`** from `state` / resolution metadata — not duplicated into kwargs unless a condition **computes** a value (wall blocks, capture-stone supplemental target).

### Timed stones

- Separate **`effect_name` per beat** (e.g. `delay_reward_setup` + `delay_reward_payout`) — one file each.
- **`action = tick`** rows collected when `cell.duration_left ~= nil`; apply runs at `duration_left == 0` after generic decrement.
- Strict defs: setup rows that set `duration_left` **must** declare `rounds` or `duration` on the definition row — schema fails at load if missing.

### Tick / round boundary

Per-round semantics use **`action = tick`** effect rows collected by `effect_manager` and invoked via **`run.apply_effect`**.

**Do not** expose `on_tick` on resolved effects. Remove `tick_objects.run_side_effects` → `on_tick` dispatch after migration.

### Removal integration (ADR 0003)

Effects that remove stones **enqueue** on `state.pending_stone_removals` via `helpers/shared/pending_removals.lua` (to be added). They do not clear board cells directly except where the beat requires immediate field mutation (e.g. solidity before lethal enqueue).

### Shared utilities

Cross-cutting helpers live under `helpers/shared/` only — not under `helpers/effects/`.

## Consequences

- New stones: add `effects/<name>.lua`, register in `effects.lua`, add spec coverage; shared math in `helpers/shared/`.
- New conditions: add `conditions/<name>.lua`, register in `conditions.lua`.
- Resolver code must call `objects.effects_conditions.run` — not helpers directly.
- ADR 0001 stage + phase model unchanged in spirit; placement order and remove stage role amended by ADR 0003.

## References

- `objects/effects_conditions/CONTEXT.md`
- `docs/effects-architecture.md`
- `mds/PRD_effects_conditions_module.md`
- GitHub issue #42
