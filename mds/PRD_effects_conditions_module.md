# PRD: Effects–Conditions Module — Per-File Registry, Action Beats, duration_left

**Status:** ready-for-agent  
**Source:** Grill-with-docs session 2026-06-18 (supersedes prior #42 layout decisions)  
**Related:** GitHub #42, ADR 0001, ADR 0002 (to be amended), root `CONTEXT.md`, `objects/effects_conditions/CONTEXT.md`  
**Triage label:** `ready-for-agent`

---

## Problem Statement

The effects–conditions module was migrated incrementally, but the result is hard to navigate: a monolithic effects registry (~2000 lines), inconsistent patterns (`EffectSchema.build`, `kwargs_from_def`, hidden `on_tick` hooks), and timer logic split across ad-hoc cell fields (`immunity_remaining`, `survival_rounds_remaining`, `board_cell_timers`) plus a side-door tick path that bypasses `action` scheduling.

Developers cannot open a stone definition, find the matching effect and condition, and immediately understand resolver behavior. Agents repeatedly reintroduced architectures the user rejected (dispatch splits, `M.apply`, `on_tick`, `kwargs_from_def`).

Timed stones mix `on_play` with hidden per-round hooks while `action = tick` exists in the enum but is unused on definitions. Duration values are sometimes hardcoded in builders instead of flowing from parameters through definitions.

## Solution

Restructure the module so **every `effect_name` and `condition_name` has its own file** with a **detailed module docstring** at the top. Thin registries (`effects.lua`, `conditions.lua`) only route by name.

Each effect file exports **`build(effect)`** returning a plain resolved table: scheduling fields plus **`apply = function(state, owner, kwargs)`** (inline closure). **No `EffectSchema.build` wrapper. No `kwargs_from_def`. No `on_tick` or other hooks** — only `apply`.

Objects declare **multiple effect rows** distinguished by **`action`** (`on_play`, `tick`, `end_of_turn`, `on_removed`, …). Timed stones use **`on_play` to set `cell.duration_left`** (from parameters via the def row) and a separate **`action = tick` row** whose `apply` runs expiry semantics when `duration_left == 0` after the generic tick stage decrements.

**`kwargs`** carries only runtime values from **conditions**. Definition fields (`value`, `rounds`, `duration`, `payout`) are read from the `effect` argument in `build` and closed over by `apply`.

**Schemas** validate definition rows at load time only; they do not construct runtime instances.

## User Stories

### Navigation and documentation

1. As a **developer**, I want one file per `effect_name` under the effects package, so that I can open a stone def and jump directly to its implementation overview.
2. As a **developer**, I want one file per `condition_name` under the conditions package, so that gating logic is equally discoverable.
3. As a **developer**, I want a detailed module docstring at the top of each effect/condition file explaining when it runs, which def fields it reads, which conditions/kwargs it expects, which shared helpers it calls, and when it no-ops, so that I do not need to read helper internals to understand behavior.
4. As a **reviewer**, I want registry files to contain routing only (no business logic, no duplicated docstrings), so that PRs adding logic to registries are obviously wrong.
5. As a **developer**, I want root `CONTEXT.md` and module `CONTEXT.md` to stay aligned with this layout, so that glossary terms match the code.

### Effect shape and apply

6. As a **Code Writer**, I want `build(effect)` to return a plain table like the pre-migration main-branch shape, so that resolved effects are easy to inspect.
7. As a **Code Writer**, I want `apply` to be an inline function on that table, so that orchestration is visible without a separate `M.apply`.
8. As a **Code Writer**, I want every resolved effect to expose **`apply` only**, so that there is no second hook API (`on_tick`, `tick`, etc.).
9. As a **Code Writer**, I want `apply` bodies to be succinct orchestration (typically validate kwargs → one or two shared helper calls → optional animation), so that files stay readable.
10. As a **Code Writer**, I want non-trivial math in `helpers/shared/`, so that effect files stay overview-sized.
11. As a **Code Writer**, I want docstrings without `@param` type annotation blocks, so that files match project preference.

### Definition fields vs kwargs

12. As a **Code Writer**, I want numeric and structural fields on effect rows to come from **`objects/parameters/*`** referenced in definitions, so that balance is never hardcoded in effect files.
13. As a **Code Writer**, I want `apply` to read `effect.value`, `effect.rounds`, `effect.duration`, etc. from the build closure, so that kwargs remain condition-only.
14. As a **Code Writer**, I want `require_kwargs` only when conditions must supply keys (e.g. `blocks` from `wall_part_of_wall`), so that simple effects like `add_points` skip it.
15. As a **Code Writer**, I want the runner to merge condition fragments and call `apply(state, owner, kwargs)` once, so that gating stays centralized.

### Multiple actions per object

16. As a **developer**, I want one object to declare multiple effect rows differing by `action`, so that lifecycle beats are explicit on the definition.
17. As a **player**, I want delay-reward stones to set a timer on play and pay out on expiry, so that survival timing is fair and predictable.
18. As a **Code Writer**, I want delay-reward stones to use `on_play` setup and `tick` payout rows, so that the pattern matches escalating stones (`on_play` + `end_of_turn` + `on_removed`).
19. As a **Code Writer**, I want `end_of_turn` rows for recurring board effects (tax, territory yield, escalating bank), so that they are not confused with countdown timers.
20. As a **Code Writer**, I want `on_removed` rows for capture penalties and bank transfers, so that removal stays explicit per ADR 0001.
21. As a **reviewer**, I want `action = tick` collected only for cells with `duration_left ~= nil`, so that tick effects do not run on non-timed stones.

### duration_left

22. As a **Code Writer**, I want placed stones to use **`cell.duration_left`** as the unified countdown field, so that timer state is consistent.
23. As a **Code Writer**, I want the generic tick stage to decrement `duration_left` without interpreting stone semantics, so that countdown stays dumb infrastructure.
24. As a **Code Writer**, I want `on_play` apply to set `duration_left` from def params, so that duration is visible on the definition row.
25. As a **Code Writer**, I want `tick` apply to handle expiry when `duration_left == 0` after decrement, so that payout/cleanup runs at the right beat.
26. As a **Code Writer**, I want ObjectInstances (temporary stances) to keep `duration.remaining_rounds` for off-board timers, aligning naming over time with `duration_left`.
27. As a **Code Writer**, I want blockade to remain an exception (durations on adjacent empty cells via placement blocks), so that we do not force a misleading `duration_left` on the blockade stone cell.

### Conditions

28. As a **Code Writer**, I want each condition file to export `eval` as its first function with a module docstring above, so that conditions mirror the effect discoverability goal.
29. As a **Code Writer**, I want the conditions registry to route `condition_name` → module `eval`, so that dispatch stays thin.
30. As a **Code Writer**, I want conditions to return `pass, fragment | nil`, so that wall stone can pass `blocks` without recomputing in the effect.

### Eliminate legacy patterns

31. As a **reviewer**, I want `on_tick` on resolved effects removed, so that all beats go through `action` + `apply`.
32. As a **reviewer**, I want `kwargs_from_def` and `EffectSchema.build` wrapping removed from builders, so that agents cannot reintroduce hidden def→kwargs injection.
33. As a **reviewer**, I want `macro`, `sub`, `accepts_kwargs`, and `_effect_def` forbidden on resolved instances, so that scheduling stays `action` + `phase` only.
34. As a **Code Writer**, I want `tick_objects` to stop calling `on_tick` directly, so that tick semantics flow through `effect_manager` + runner like other actions.

### Schema and validation

35. As a **Code Writer**, I want EffectSchema and ConditionSchema to validate defs at load time, so that missing `rounds`/`duration` on timed setup rows fail early.
36. As a **Code Writer**, I want condition kwargs key collisions rejected at schema time, so that merged kwargs are unambiguous.

### Migration quality

37. As a **Code Writer**, I want the full unit/integration/visual suite green after migration, so that behavior is preserved.
38. As a **Code Writer**, I want anti-capture and similar stones to declare `duration = P.*` on the def row explicitly, so that parameters are visible without reading builder fallbacks.

## Implementation Decisions

### Package layout

```
objects/effects_conditions/
  EffectSchema.lua          # load-time validation only
  ConditionSchema.lua
  scheduling.lua            # ACTION / PHASE enums
  effects.lua               # registry: resolve → effects/<name>.build
  conditions.lua            # registry: eval router → conditions/<name>.eval
  run.lua                   # conditions → merge kwargs → apply
  effects/
    <effect_name>.lua       # module docstring + build(effect)
  conditions/
    <condition_name>.lua    # module docstring + eval(...)
  helpers/
    shared/                 # all reusable logic
```

Delete or stop using: monolithic inlined builders, `helpers/effects/` per-effect files (logic moves to shared grouped by domain), `on_tick` dispatch in tick stage, `kwargs_from_def`, `EffectSchema.build` as factory.

### Resolved effect table (builder output)

```lua
{
  type = "DELAY_REWARD_SETUP",
  action = effect.action or scheduling.ACTION.on_play,
  phase = effect.phase or scheduling.PHASE.points,
  priority = effect.priority or default,
  value = effect.value,          -- copied from def when present
  conditions = effect.conditions,
  apply = function(state, owner, kwargs)
    -- 3–8 lines orchestration; effect.rounds from closure
  end,
}
```

Forbidden on resolved instances: `on_tick`, `kwargs_from_def`, `macro`, `sub`, `accepts_kwargs`, `_effect_def`.

### Parameter flow

```
objects/parameters/stones.lua (balance)
    → objects/definitions/stones.lua (rounds = P.points_delay_rounds)
    → build(effect) closure
    → on_play apply sets cell.duration_left = effect.rounds
```

Effect files must not literal hardcode round counts or payouts.

### Action beats and timed stones

| action | When collected | Typical role |
|--------|----------------|--------------|
| `on_play` | Stone played | Setup, scoring, set `duration_left` |
| `tick` | EOT, cell has `duration_left ~= nil`, after decrement | Expiry payout/cleanup at `duration_left == 0` |
| `end_of_turn` | EOT, stone on board | Recurring (tax, escalating bank, territory) |
| `on_removed` | Explicit removal dispatch | Capture transfer, money penalty |

**EOT pipeline order:**

1. Generic tick stage decrements `duration_left` (and legacy fields until migrated).
2. `effect_manager` runs `action = tick` phase passes for eligible cells.
3. Self-destruct / timer expiry removal (if `duration_left` hits 0 and stone should leave).
4. `effect_manager` runs `action = end_of_turn` phase passes.

### duration_left migration map

| Legacy field | Target |
|--------------|--------|
| `immunity_remaining` | `duration_left` (anti_capture) |
| `survival_rounds_remaining` | `duration_left` (delay_reward) |
| `board_cell_timers` | `duration_left` or unified cell field (self_destruct) |
| `placement_blocks` | unchanged (blockade exception) |

Companion fields (e.g. `delay_payout` until payout) may remain until expiry apply clears them.

### Wall stone exemplar (unchanged contract)

- Def: `on_play` + `wall_stone` + condition `wall_part_of_wall`.
- Condition returns `{ blocks = n }` via shared wall group math.
- Effect `apply`: `require_kwargs({blocks})` → shared scoring + animation.

### Conditions registry

Route `M.eval(condition_def, state, owner)` → `conditions/<name>.eval(...)`. No private helper lookup tables required; explicit requires per module are fine.

### Resolver integration

- `effect_manager.apply_phase_pass` must support `action = tick` collection from board scan (same seam as `end_of_turn`).
- `tick_objects.run_side_effects` and `resolved_tick_handler` / `on_tick` path removed after tick action migration.
- `run.apply_effect` remains sole path to `apply` for collected effects.

### Prototype snippet (builder shape)

```lua
-- effects/delay_reward_setup.lua (conceptual)
function M.build(effect)
  return {
    type = "DELAY_REWARD_SETUP",
    action = scheduling.ACTION.on_play,
    phase = scheduling.PHASE.points,
    apply = function(state, owner, kwargs)
      delay_reward.setup(state, owner, effect.rounds, effect.payout)
    end,
  }
end

-- effects/delay_reward_payout.lua
function M.build(effect)
  return {
    type = "DELAY_REWARD_PAYOUT",
    action = scheduling.ACTION.tick,
    phase = scheduling.PHASE.points,
    apply = function(state, owner, kwargs)
      if kwargs.cell.duration_left ~= 0 then return end
      delay_reward.payout_and_clear(state, kwargs.cell)
    end,
  }
end
```

### Stones requiring action review (timed / multi-beat)

| Stone | Expected rows |
|-------|----------------|
| delay_reward_stone | `on_play` setup + `tick` payout |
| anti_capture_stone | `on_play` set duration (`tick` optional/minimal) |
| self_destruct_timed_stone | `on_play` points + timer; removal via stage at 0 |
| blockade_stone | `on_play` register + `tick` shrink (placement_blocks) |
| territory_to_points_stone | `end_of_turn` only |
| tax_stone | `end_of_turn` only |
| territory_to_multiplier_stone | `on_play` snapshot + `end_of_turn` |
| escalating_points_stone | `on_play` init + `end_of_turn` + `on_removed` |
| escalating_money_stone | `end_of_turn` + `on_removed` |

## Testing Decisions

**Good tests** assert scores, board cells, legality, money, and messages — not which shared helper ran.

### Seams (highest first)

| Seam | Proves |
|------|--------|
| `resolver` / `resolve_round` end-to-end | delay_reward payout on correct EOT; tax each turn; escalating bank |
| `effect_manager.apply_phase_pass` with `action = tick` | tick rows collected when `duration_left` set; no-op while counting; payout at 0 |
| `run.apply_effect` | kwargs merge, condition gate, missing kwargs error |
| `EffectSchema.validate` / `ConditionSchema.validate` | required duration fields; kwargs collision |
| `spec/integration/temporary_stance_turn_spec.lua` | stance duration unchanged by stone tick work |
| `spec/unit/effects_wall_spec.lua` | wall kwargs path after file split |

### Prior art

- `spec/unit/conditions_spec.lua`
- `spec/unit/effects_spec.lua`, `spec/unit/effects_wall_spec.lua`
- `spec/integration/effect_conditions_integration_spec.lua`
- `spec/integration/temporary_stance_turn_spec.lua`
- `spec/visual/stones_scoring/*`

### New / updated tests

- Tick action: delay_reward pays exactly after N EOTs; no payout before.
- `duration_left` decrements generically; effect does not decrement.
- Registry: each migrated effect file has build returning inline `apply` only.
- anti_capture: def row includes `duration = P.anti_capture_duration_rounds`.

## Out of Scope

- Reintroducing `helpers/effects/` per-effect logic files (use `helpers/shared/` grouped by domain).
- `kwargs_from_def` or `EffectSchema.build` as runtime factory.
- `on_tick` / hidden hooks on resolved effects.
- New stone gameplay beyond wiring existing stones into the new layout.
- AI/MCTS calling `resolve_round`.
- Animations module restructure.
- Forcing `duration_left` onto blockade adjacent cells in this pass (document exception only).

## Further Notes

- **Supersedes** prior #42 decisions: monolithic builders, `helpers/effects/` dispatch split, `on_tick`, `kwargs_from_def`, EffectSchema.build wrapping.
- **ADR 0002** tick-hooks section is obsolete; amend when implementing tick action migration.
- **Module CONTEXT.md** may contain stale lines (`on_tick` in resolved table); align during Phase 1.
- Read order for agents: root `CONTEXT.md` → `objects/effects_conditions/CONTEXT.md` → this PRD.
- Prior handoff and agent work on branch may be uncommitted; verify test baseline before large moves.
