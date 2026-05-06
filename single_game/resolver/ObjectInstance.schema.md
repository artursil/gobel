# ObjectInstance Schema

Object instances are mutable runtime entities derived from definitions.

```lua
ObjectInstance = {
  instance_id = "string",
  def_id = "string",
  object_type = "stone" | "card" | "stance",

  owner = "A" | "B" | "run",
  source = "starter" | "reward" | "shop" | "generated",

  level = 1,
  max_level = 5,
  experience = 0,

  base = {
    rarity = "common",
    probability = 1.0,
    defense = 1,
    cost = 1,
  },

  mutable = {
    rarity = nil,
    probability = nil,
    defense = nil,
    cost = nil,
  },

  extra_effects = {},
  removed_effect_indexes = {},

  status = {
    disabled = false,
    disabled_reason = nil,
    disabled_until_turn = nil,
    disabled_until_game = nil,
    permanent_disable = false,
    uses_left = nil,
    destroyed = false,
    evolve = {
      target_def_id = nil,
      at_turn = nil,
      at_game = nil,
      condition = nil,
    },
  },

  telemetry = {
    total_uses = 0,
    uses_this_game = 0,
    turns_unplayed = 0,
    games_unplayed = 0,
    last_used_turn = nil,
    last_used_game = nil,
  },
}
```
