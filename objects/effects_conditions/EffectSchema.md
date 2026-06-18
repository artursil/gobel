# Effect schema

Unified effect definition for stones, cards, and stances. Definitions are **data only**; gameplay lives in `objects/effects_conditions/effects.lua` builder functions.

## Definition row (`EffectDef`)

```lua
{
  effect_name = "add_points",   -- required; builder key M[effect_name]
  action = "on_play",           -- required with phase (or legacy when + phase)
  phase = "points",             -- territory | points | mult

  priority = 10,
  value = 10,                   -- number or structured table
  params = {},
  duration = nil,
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
  rounds = nil,
  payout = nil,
  stone_kind = nil,
}
```

## Rules

- Effects on object definitions are **immutable data**.
- `M.resolve(effect_def)` calls `M[effect_name](effect_def)` — one builder per effect name.
- **`macro` and `sub` are removed** — use `action` + `phase`.
- Conditions are validated separately via `ConditionSchema`.

## Builder contract

Each `M.<effect_name>(effect)` returns a builder table consumed by `EffectSchema.build`:

```lua
function M.wall_stone(effect)
  return EffectSchema.build(effect, {
    type = "WALL_STONE",
    default_phase = "points",
    default_action = "on_play",
    default_priority = stone_params.wall_effect_priority,
    apply = function(state, owner, kwargs)
      -- kwargs.blocks from conditions; shared math from helpers/shared/*
    end,
  })
end
```

## Resolved runtime instance

`EffectSchema.build(effect_def, opts)` merges definition scheduling with builder defaults:

| Field | Role |
|-------|------|
| `type` | Uppercase effect kind (e.g. `"WALL_STONE"`) |
| `effect_name` | Dispatch key from definition |
| `action`, `phase` | Scheduling — definition overrides builder defaults |
| `priority`, `value`, `params`, … | From definition (with defaults applied) |
| `conditions` | Gated by runner before apply |
| `apply(state, owner, kwargs)` | Always kwargs arity |
| `on_tick(...)` | Optional; tick lifecycle only |

Forbidden on resolved instances: `accepts_kwargs`, `_effect_def`, `macro`, `sub`.

## Validation

`EffectSchema.validate(effect_def, object_id)` — authoritative at load time. See `ConditionSchema` for condition rows.
