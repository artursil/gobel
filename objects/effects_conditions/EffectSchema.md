# Effect schema

Unified effect definition for stones, cards, and stances. Definitions are **data only**; gameplay lives in `objects/effects_conditions/effects/<effect_name>.lua`.

See also: [ADR 0002](../../docs/adr/0002-effects-conditions-module.md), root `CONTEXT.md`.

## Definition row (`EffectDef`)

```lua
{
  effect_name = "add_points",   -- required; routes to effects/<effect_name>.lua
  action = "on_play",           -- required with phase (or legacy when + phase)
  phase = "points",             -- territory | points | mult

  priority = 10,
  value = 10,                   -- number or structured table
  params = {},
  duration = nil,               -- required on setup rows that set duration_left (strict)
  scope = "game",

  probability = nil,
  conditions = {},              -- array of ConditionDef

  target = {
    selector = "self",
    filters = {},
  },

  tags = {},

  territory_step = nil,
  delay_rounds = nil,
  immediate_points = nil,
  rounds = nil,                 -- required on timed setup rows (strict)
  payout = nil,
  stone_kind = nil,
}
```

## Rules

- Effects on object definitions are **immutable data**.
- Registry `M.resolve(effect_def)` calls `effects/<effect_name>.lua` **`build(effect_def)`**.
- **`macro` and `sub` are removed** — use `action` + `phase`.
- Timed setup rows that set `cell.duration_left` **must** declare `rounds` or `duration` from parameters — schema fails at load if missing.
- Conditions are validated separately via `ConditionSchema`.

## Builder contract

Each `effects/<effect_name>.lua` exports **`build(effect)`** returning a plain table:

```lua
function M.build(effect)
  return {
    type = "WALL_STONE",
    action = effect.action or scheduling.ACTION.on_play,
    phase = effect.phase or scheduling.PHASE.points,
    priority = effect.priority or stone_params.wall_effect_priority,
    value = effect.value,
    conditions = effect.conditions,
    apply = function(state, owner, kwargs)
      require_kwargs.require_kwargs(kwargs, { "blocks" })
      -- shared math from helpers/shared/*
    end,
  }
end
```

**Do not** use `EffectSchema.build` as a factory. **Do not** use `kwargs_from_def`.

## Resolved runtime instance

| Field | Role |
|-------|------|
| `type` | Uppercase effect kind (e.g. `"WALL_STONE"`) |
| `action`, `phase` | Scheduling — definition overrides builder defaults |
| `priority`, `value`, … | From definition |
| `conditions` | Gated by runner before apply |
| `apply(state, owner, kwargs)` | Inline orchestration only |

Forbidden on resolved instances: `on_tick`, `kwargs_from_def`, `accepts_kwargs`, `_effect_def`, `macro`, `sub`.

## Validation

`EffectSchema.validate(effect, object_id)` runs at load time only. It does **not** construct runtime instances.
