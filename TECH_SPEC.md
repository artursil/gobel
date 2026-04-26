# TECH_SPEC.md

## Purpose

This document defines the technical contracts for implementing the MVP systems in:
- `SYSTEMS.md`
- `CONTENT.md`
- `GAME_RULES.md`

It specifies module boundaries, shared data shapes, resolver flow, and integration points with existing code.

## Implementation Target

Language/runtime:
- Lua
- LÖVE framework

Current integration anchor:
- existing board/rules/scoring loop in `game.lua`, `rules.lua`, `scoring.lua`, `render.lua`, `main.lua`

## Module Layout

### Existing modules to preserve

- `board.lua`
- `rules.lua`
- `scoring.lua`
- `patterns.lua`
- `ai.lua`

### New modules

- `match_state.lua`
  - create and own full `MatchState`
  - expose typed getters/setters-style helper functions

- `content.lua`
  - load and expose normalized content definitions from `CONTENT.md` equivalents encoded in Lua tables
  - provide id-based lookup for stones/cards/poses

- `economy.lua`
  - money operations (`get`, `gain`, `spend`, `can_spend`)

- `energy.lua`
  - energy operations (`refresh`, `can_spend`, `spend`)

- `pouch.lua`
  - stone bag operations (`draw`, `remaining_count`, `shuffle_init`)

- `deck.lua`
  - deck/hand/discard operations (`draw_to_hand_target`, `play_from_hand`, `discard_card`, `reshuffle_discard_into_deck`)

- `poses.lua`
  - passive trigger registration and trigger dispatch helpers

- `resolver.lua`
  - validate action by phase
  - build events
  - process events in deterministic order
  - enqueue messages
  - recalc derived score

- `messages.lua`
  - message queue operations (`push`, `peek`, `pop`, `recent`)

## Data Contracts

All contracts use normalized Lua tables with explicit fields.
IDs are string keys defined in content tables.

### Enums

Canonical enum strings:
- sides: `black`, `white`
- phases:
  - `TURN_START`
  - `DRAW_PHASE`
  - `MAIN_PHASE`
  - `PLACE_PHASE`
  - `RESOLVE_PHASE`
  - `TURN_END`
  - `MATCH_END`
- action types:
  - `PLAY_CARD`
  - `PLACE_STONE`
  - `PASS_TURN`
- effect types:
  - `ADD_POINTS`
  - `ADD_MULT`

### MatchState schema

```lua
{
  board = <board-grid>,
  to_play = "black" | "white",
  phase = <phase>,
  turn_number = <integer>,
  ended = <boolean>,
  end_reason = "none" | "two_passes" | "terminal_no_actions",
  winner = "none" | "black" | "white" | "draw",
  ko_ban = { row = <integer>, col = <integer> } | nil,
  consecutive_passes = <integer>,
  messages = {
    queue = { <MessageEvent>, ... },
    recent = { <MessageEvent>, ... }
  },
  players = {
    black = <PlayerState>,
    white = <PlayerState>
  },
  rng = {
    seed = <integer>,
    state = <opaque>
  }
}
```

### PlayerState schema

```lua
{
  side = "black" | "white",
  score = {
    points = <integer>,
    mult = <integer>,
    total = <integer>
  },
  resources = {
    energy_current = <integer>,
    energy_max = <integer>,
    money = <integer>
  },
  stones = {
    pouch = { ids = { <stone_id>, ... } },
    active_stone = <stone_id> | nil
  },
  cards = {
    deck = { ids = { <card_id>, ... } },
    hand = { ids = { <card_id>, ... } },
    discard = { ids = { <card_id>, ... } },
    hand_target_size = <integer>
  },
  poses = {
    fixed = { <pose_id>, ... },
    swappable = { <pose_id>, ... }
  },
  prisoners = <integer>
}
```

### Action payload schemas

#### PLAY_CARD

```lua
{
  actor = "black" | "white",
  type = "PLAY_CARD",
  payload = {
    hand_index = <integer>
  }
}
```

#### PLACE_STONE

```lua
{
  actor = "black" | "white",
  type = "PLACE_STONE",
  payload = {
    row = <integer>,
    col = <integer>
  }
}
```

#### PASS_TURN

```lua
{
  actor = "black" | "white",
  type = "PASS_TURN",
  payload = {}
}
```

### Event schema

```lua
{
  kind = "MESSAGE" | "APPLY_EFFECT" | "BOARD_UPDATE" | "DRAW" | "STATE_FLAG",
  actor = "black" | "white",
  source = {
    type = "CARD" | "STONE" | "POSE" | "SYSTEM",
    id = <string>
  },
  effect = {
    type = "ADD_POINTS" | "ADD_MULT" | nil,
    value = <integer> | nil
  },
  payload = <table>
}
```

## Resolver Contract

`resolver.lua` is the only gameplay mutation entry point for user/AI actions.

Public API:
- `submit_action(match_state, action) -> result`

Result schema:

```lua
{
  ok = <boolean>,
  error = <string|nil>,
  consumed_phase = <phase>,
  emitted_events = <integer>
}
```

### Resolver invariants

- no partial mutation on invalid actions
- deterministic event order
- all score changes emitted as message then applied
- no direct board/resource mutation from UI layer

### Resolver flow

1. validate actor and phase
2. validate action payload
3. compile event list for action
4. process each event FIFO:
   - emit message event first
   - apply effect/state event
   - recompute derived score
5. phase transition and end-condition checks

## Derived Score Contract

Per side:
- `points_base` and `mult_base` remain sourced from existing scoring logic on board state
- `points_bonus` and `mult_bonus` are accumulated resolver deltas from cards/stones/poses
- final displayed values:
  - `points = points_base + points_bonus`
  - `mult = mult_base + mult_bonus`
  - `total = points * mult`

Implementation note:
- keep board scoring untouched in `scoring.lua`
- store resolver bonuses in player state to avoid rewriting board scoring

## Input/Runtime Integration

### `main.lua`

Replace direct calls to board mutation paths with resolver submissions:
- card click -> `PLAY_CARD`
- board click in place phase -> `PLACE_STONE`
- pass key -> `PASS_TURN`

### `game.lua`

Refactor from owner of ad hoc game state to coordinator around:
- `match_state.new_match`
- `resolver.submit_action`
- AI action dispatch via same resolver

### `ai.lua`

AI produces actions only:
- choose `PLACE_STONE` or `PASS_TURN`
- optional future `PLAY_CARD`

AI must not call `rules.try_play` directly for authoritative mutation.

## Rendering Contract

`render.lua` reads only from `MatchState` and never mutates gameplay state.

Required read fields for target UI:
- top boxes:
  - player/opponent points, mult, total
- side panels:
  - poses, energy, money (player only)
- bottom zones:
  - pouch remaining, deck remaining, hand cards, active stone
- message board:
  - current queue head and recent messages

`layout.lua` must expose named regions:
- `score_player`
- `score_opponent`
- `board`
- `left_panel`
- `right_panel`
- `pouch_panel`
- `deck_panel`
- `hand_panel`
- `active_stone_panel`
- `message_panel`

## Initialization Contract

`match_state.new_match(mode, seed)` must:
- initialize board and turn fields
- initialize players using starter content from `content.lua`
- seed deterministic RNG
- set initial phase to `TURN_START`
- enqueue initial message

Defaults:
- `energy_max = 3`
- `money = 0`
- `hand_target_size = 5`

## Determinism and Safety

Determinism:
- all draws through seeded RNG functions
- stable ordered arrays for deck/pouch/hand/events
- no reliance on unordered table iteration for gameplay decisions

Safety:
- action validation before mutation
- bounds checks for hand index and board coordinates
- illegal actions return `ok = false` with reason string

## Migration Plan from Current Code

1. introduce `match_state.lua` and `content.lua` without replacing existing flow
2. add `resolver.lua` and route pass/place actions through it
3. add energy/economy/deck/pouch/poses modules
4. switch UI reads to new state fields
5. remove obsolete ad hoc fields in old `game` table once fully migrated

## Test Contract

Minimum tests required before MVP complete:
- card play consumes energy and applies expected effect
- stone placement applies expected placement effect
- pose trigger on turn start applies expected effect
- message-before-score-update ordering is preserved
- two-pass end condition resolves winner correctly

