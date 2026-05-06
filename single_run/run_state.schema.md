# Run State Schema

`run_state` persists across multiple games in one run.

```lua
run_state = {
  meta = {
    run_id = "string",
    ruleset_version = "v1",
  },

  seed = {
    base_seed = 123456789,
    streams = {
      -- per-key counters only (no mutable per-stream state blob)
      ["draw.cards.player"] = { calls = 0 },
      ["draw.stones.player"] = { calls = 0 },
      ["effect.destroy_stone"] = { calls = 0 },
      ["shop.roll"] = { calls = 0 },
    },
  },

  progression = {
    game_index = 1,
    wins = 0,
    losses = 0,
    mini_bosses_defeated = 0,
    bosses_defeated = 0,
  },

  resources = {
    money = 0,
    max_stance_slots = 2,
    rerolls = 0,
  },

  inventory = {
    stones = { instance_ids = {} },
    cards = { instance_ids = {} },
    stances = { instance_ids = {} },
  },

  instance_store = {}, -- instance_id -> ObjectInstance

  destroyed = {
    stones = {},
    cards = {},
    stances = {},
  },

  disabled = {}, -- instance_id -> disable metadata

  probability_modifiers = {
    by_rarity = { common = 1.0, uncommon = 1.0, rare = 1.0 },
    by_type = { stone = 1.0, card = 1.0, stance = 1.0 },
    tags = {},
  },

  history = {
    games = {},
    counters = {
      total_cards_played = 0,
      total_stones_played = 0,
      total_captures = 0,
      by_instance_use = {},
    },
  },

  pending_effects = {},
}
```

## Per-key RNG implementation contract

- Output must be computed from `(base_seed, key, calls)`.
- On consume:
  1. read `calls`
  2. compute value
  3. increment `calls`

This ensures deterministic replay and avoids hidden mutable RNG state.
