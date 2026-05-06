# Player Game State Schema

`PlayerGameState` is nested under `game_state.players.A/B`.

```lua
PlayerGameState = {
  owner = "A", -- or "B"

  resources = {
    energy_current = 3,
    energy_max = 3,
    money_delta_this_game = 0,
  },

  limits = {
    cards_per_turn = 999,
    stones_per_turn = 1,
    hand_size_cards = 4,
    hand_size_stones = 6,
  },

  card_zones = {
    draw_pile = { instance_ids = {} },
    hand = { instance_ids = {} },
    discard = { instance_ids = {} },
    exhaust = { instance_ids = {} },
    destroyed = { instance_ids = {} },
  },

  stone_zones = {
    pouch = { instance_ids = {} },
    hand = { instance_ids = {} },
    board = { instance_ids = {} },
    captured = { instance_ids = {} },
    destroyed = { instance_ids = {} },
  },

  stances = {
    visible = { instance_ids = {} },
    hidden = { instance_ids = {} }, -- fake stances / lingering card effects
  },

  counters = {
    prisoners_captured = 0,
    stones_captured = 0,
    cards_played = 0,
    stones_played = 0,
    turns_without_playing_card = 0,
    turns_without_playing_stone = 0,
  },
}
```

## Rules

- Zone movement must preserve instance identity (`instance_id`), not duplicate definition IDs.
- Temporary disables and usage limits should be enforced through instance status, not zone hacks.
