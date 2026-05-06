# Game State Schema

`game_state` is the single-game runtime container. It resets between games in a run.

## Top-level shape

```lua
game_state = {
  meta = {
    game_id = "string",
    game_index = 1,
    phase = "TURN_START",
    turn_number = 1,
    round_number = 1,
    ended = false,
    end_reason = "none",
    winner = "none",
  },

  board = {
    grid = {}, -- board cells
    ko_ban = nil,
    placement_mask = nil, -- optional blocked/allowed map
    territory_value = {}, -- per-cell value multipliers
  },

  players = {
    A = PlayerGameState,
    B = PlayerGameState,
  },

  turn = {
    to_play = "A",
    consecutive_passes = 0,
    cards_played_this_turn = 0,
    stones_played_this_turn = 0,
  },

  scores = {
    turn_bonus = { A = 1, B = 1 },
    territory = { A = 0, B = 0 },
    points = { A = 0, B = 0 },
    plus_mult = { A = 1, B = 1 },
    x_mult = { A = 1, B = 1 },
    total = { A = 0, B = 0 },
  },

  effects = {
    active = {}, -- timed effects active for this game
    distance_modifiers = {
      default_bonus = 0,
      by_stone_key = {},
    },
    listeners = {}, -- event_name -> listener rules
  },

  runtime = {
    last_played = {
      stone_instance_id = nil,
      card_instance_id = nil,
      by_player = {
        A = { stone_instance_id = nil, card_instance_id = nil },
        B = { stone_instance_id = nil, card_instance_id = nil },
      },
    },
    sequences = { A = {}, B = {} },
    predictions = {},
    message_queue = {},
    score_events = {},
  },
}
```

## Rules

- All game-local effects mutate `game_state`.
- No run-persistent mutation should be written directly here.
- Resolver reads and writes game behavior only through this schema.
