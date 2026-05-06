# Effect Schema

Unified effect definition used by stones/cards/stances.

```lua
EffectDef = {
  effect_name = "add_points",
  phase = "points",
  priority = 10,

  value = 10,
  params = {},
  duration = nil,
  scope = "game", -- "turn" | "round" | "game" | "run"

  probability = nil, -- base chance (optional)
  conditions = {
    -- array of ConditionDef
  },

  target = {
    selector = "self",
    filters = {},
  },

  tags = {},
}
```

## Rules

- Effects are data only.
- Resolver dispatches by `effect_name` into `objects/effects.lua`.
- Effect logic never lives in resolver loops.
