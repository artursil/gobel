# ADR 0002: Effects–conditions module layout and kwargs contract

**Status:** Accepted  
**Date:** 2026-06-17  
**Issue:** GitHub #42 (Phase 5)

## Context

Effect and condition logic previously lived across top-level `objects` shims (`effects`, `conditions`, `effects_helpers`, `helper_effects`, `effect_enums`, `effect_schedule`, `effect_factory`) and a duplicate resolver schema (`single_game/resolver/Effect.lua`). Phases 0–4 migrated behavior into `objects/effects_conditions/`; Phase 5 removes compatibility shims.

## Decision

### Module layout

```
objects/effects_conditions/
  EffectSchema.lua      # validation + runtime instances; re-exports scheduling
  ConditionSchema.lua   # condition row validation
  scheduling.lua        # ACTION/PHASE enums, schedule parsing, build()
  effects.lua           # thin effect_name → helper dispatch
  conditions.lua        # thin condition_name → helper dispatch
  run.lua               # sole resolver entry: eval conditions → merge kwargs → apply
  helpers/
    effects/            # apply(state, owner, kwargs)
    conditions/         # eval(state, owner, condition_def) → pass, fragment
    shared/             # reusable utilities (placement reads, capture cooldown, copper count, …)
```

Top-level shims (`objects/effects.lua`, `objects/conditions.lua`, `objects/effects_helpers.lua`, scheduling shims, resolver `Effect.lua`) are deleted. Callers require `objects.effects_conditions.*` directly.

### Kwargs contract

1. **Effect apply:** `apply(state, owner, kwargs)` — always three arguments after dispatch.
2. **Condition eval:** `eval(state, owner, condition_def?) → pass: boolean, fragment: table | nil`.
3. **Runner merge:** All conditions on an effect must pass; non-nil fragments merge into one `kwargs` table before `apply`.
4. **Required keys:** Helpers call `require_kwargs` and error when a required key is absent.
5. **Placement / removal context:** Read from `state`, placement record, or resolution metadata inside helpers — not as extra `apply` parameters.

### Shared utilities

Cross-cutting helpers (capture cooldown, placement coords, copy-right, escalating bank storage, connected-group sizing) live under `helpers/shared/`.

### Tick hooks

Effects with per-round cell or board-zone state (`blockade_adjacent`, `anti_capture_immunity`, `delay_reward_survival`) expose `on_tick` on the resolved effect table. Tick implementations live in the corresponding `helpers/effects/*` module alongside `apply`.

## Consequences

- New stones: add `helpers/effects/<name>.lua`, register in `effects.lua`, add spec coverage.
- New conditions: add `helpers/conditions/<name>.lua` and register in `conditions.lua`.
- Resolver code must call `objects.effects_conditions.run` — not helpers directly.
- ADR 0001 pipeline (stages + phased apply) unchanged; only module paths and kwargs arity are normative here.

## References

- `objects/effects_conditions/CONTEXT.md`
- `docs/effects-architecture.md`
- GitHub issue #42
