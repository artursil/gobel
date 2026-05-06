# Condition Schema

Conditions gate effect execution.

```lua
ConditionDef = {
  condition_name = "prisoners_captured_at_least",
  value = 2,
  params = {},
}
```

## Condition context

```lua
ConditionContext = {
  run_state = run_state,
  game_state = game_state,

  actor = "A" | "B",
  opponent = "A" | "B",

  source_instance_id = "string",
  source_def_id = "string",
  source_object_type = "stone" | "card" | "stance",

  action = {
    action_type = "PLAY_CARD" | "PLACE_STONE" | "PASS_TURN",
    payload = {},
  },

  trigger = {
    event_name = "on_play" | "on_capture" | "on_turn_start" | "on_opponent_move",
    payload = {},
  },

  selected_targets = {
    row = nil,
    col = nil,
    instance_id = nil,
  },

  rng = {
    next_float = function(key) end,
    next_int = function(key, n) end,
  },
}
```

## Rules

- Conditions are evaluated only through `objects/conditions.lua`.
- Unknown condition behavior must be explicitly defined (prefer fail-closed in production).
