# SYSTEMS.md

## Purpose

This document defines the MVP single-match runtime systems used by gameplay, UI, and tests.
It is normative for implementation.

## MVP Boundary

Included:
- One standalone match (PvP and PvC)
- Board placement loop
- Stone pouch draw and use
- Card deck, hand, discard, play
- Energy and money resources
- Passive effects (Poses)
- Action resolver and message queue
- Live score display and winner resolution

Excluded:
- Map/run progression
- Shops/events/reward screens
- Save/load
- Permanent unlock progression

## Core Entities

### MatchState

Contains:
- `board`: board grid state
- `to_play`: active side (`black` or `white`)
- `phase`: current phase of turn state machine
- `turn_number`: integer starting at `1`
- `ended`: boolean
- `end_reason`: enum
- `winner`: enum (`black`, `white`, `draw`, `none`)
- `ko_ban`: optional coordinate from rules engine
- `consecutive_passes`: integer
- `message_queue`: FIFO of UI messages/events
- `players.black`: `PlayerState`
- `players.white`: `PlayerState`

### PlayerState

Contains:
- `score`:
  - `points`
  - `mult`
  - `total`
- `resources`:
  - `energy_current`
  - `energy_max`
  - `money`
- `stones`:
  - `pouch` (remaining draw pool)
  - `playable_stones` (stone options currently available to pick from)
  - `selected_stone` (stone selected for next placement)
- `cards`:
  - `deck`
  - `hand`
  - `discard`
- `poses`:
  - `fixed` (chosen before run, immutable in match)
  - `swappable` (can be replaced during run, but no replacement UI in MVP)
- `prisoners`

### Action

Supported MVP actions:
- `PLAY_CARD`
- `PLACE_STONE`
- `PASS_TURN`

Each action includes:
- `actor` (`black` or `white`)
- `type`
- typed payload:
  - card index or card id
  - board coordinate
  - no payload for pass

## Turn State Machine

Turn phases are deterministic and strict:

1. `TURN_START`
2. `DRAW_PHASE`
3. `MAIN_PHASE`
4. `PLACE_PHASE`
5. `RESOLVE_PHASE`
6. `TURN_END`
7. next player `TURN_START`

### Phase Details

#### 1) TURN_START

For active player:
- set `energy_current = energy_max`
- clear transient turn flags
- enqueue message: `"Turn start: <color>"`

Transition: `TURN_START -> DRAW_PHASE`

#### 2) DRAW_PHASE

For active player:
- refresh `playable_stones` from current pouch availability
- if `selected_stone` is empty and playable options exist, auto-select first option
- draw cards until hand size reaches `HAND_TARGET_SIZE`

MVP constants:
- `HAND_TARGET_SIZE = 5`

If deck is empty during draw:
- reshuffle discard into deck
- continue draw
- if both empty, draw stops

Transition: `DRAW_PHASE -> MAIN_PHASE`

#### 3) MAIN_PHASE

Active player may:
- play zero or more cards via `PLAY_CARD`
- stop card plays voluntarily

Constraints:
- card can only be played if:
  - card is in hand
  - `energy_current >= card.energy_cost`
  - card target/predicate is valid
- each successful card:
  - consumes energy
  - moves card from hand to discard unless card defines different zone behavior
  - creates one or more resolver events

Player cannot place stone from `MAIN_PHASE`.

Exit condition:
- explicit "end main phase" command

Transition: `MAIN_PHASE -> PLACE_PHASE`

#### 4) PLACE_PHASE

Active player must choose one:
- `PLACE_STONE` using `selected_stone`
- `PASS_TURN`

`PLACE_STONE` legality:
- board legality checked through rules engine
- if illegal, action rejected and player remains in `PLACE_PHASE`

On successful `PLACE_STONE`:
- apply board update, captures, ko ban
- consume one stone of the selected kind from pouch
- refresh `playable_stones`
- keep selected kind if still available, otherwise select first available option
- reset `consecutive_passes = 0`

On `PASS_TURN`:
- increment `consecutive_passes`

Transition:
- `PLACE_PHASE -> RESOLVE_PHASE`

#### 5) RESOLVE_PHASE

Resolve all queued gameplay effects produced this turn in defined order:
1. immediate action effects (card and placement direct effects)
2. reactive pose effects
3. derived state recalculations (score, totals, counters)

Message ordering rule:
- For each effect event:
  - enqueue user-visible message first
  - apply effect second
  - recompute derived score after effect

This guarantees message-before-score-update behavior.

Transition: `RESOLVE_PHASE -> TURN_END`

#### 6) TURN_END

Check termination:
- if `consecutive_passes >= 2`, match ends
- if one side cannot place because no stones remain and pass rules trigger end, match ends
- otherwise continue

If not ended:
- switch `to_play` to opponent
- increment `turn_number`

Transition:
- ended -> `MATCH_END`
- not ended -> next player `TURN_START`

## Resolver and Event Ordering

All gameplay state changes must go through one resolver pipeline.

### Pipeline

For each accepted action:
1. validate action in current phase
2. create event list
3. process events FIFO
4. after each event:
  - emit message
  - mutate state
  - recalc derived values
5. run end-of-phase checks

No direct state mutation from UI input handlers.

## Scoring Lifecycle

At minimum, recalc score:
- after successful card play effect
- after successful stone placement
- after any pose effect that changes points/mult/board/resource rule
- at end of `RESOLVE_PHASE`

Score formula:
- `total = points * mult`

MVP points/mult source:
- existing scoring module remains source of truth unless overridden by defined effect in resolver

## Resource Rules

### Energy

- refresh to max at `TURN_START`
- spent only by card play
- cannot go below zero
- if insufficient energy, card play is rejected

### Money

- non-negative integer
- updated only via resolver events from cards/poses/system rules
- no shop spending in MVP

## Stone System Rules

- stone draw source is pouch
- UI shows a stone selection row with currently playable stone options
- player must have one selected stone kind to place
- pass does not consume stones
- if pouch is empty and no playable stone options exist:
  - player may still pass
  - placement unavailable

## Card System Rules

- hand target size is fixed (`5`)
- deck/discard reshuffle allowed only when deck empty and draw requested
- cards are played only in `MAIN_PHASE`
- cards cannot be played in opponent turn

## Pose Rules

Two categories in state:
- fixed poses
- swappable poses

MVP runtime behavior:
- both categories are active passives during match
- replacement mechanics are out of scope for MVP match UI
- pose effects are executed only via resolver triggers

## End Conditions and Winner

MVP end triggers:
- two consecutive passes
- hard no-action terminal state defined by implementation (if both sides cannot place and no actionable cards)

Winner decision:
- compare final `total` score
- higher total wins
- equal totals -> draw

## PvP and PvC Execution

### PvP

- both sides use same state machine and input flow

### PvC

- human uses full state machine
- AI action selection feeds same action types into resolver
- AI does not mutate board/state directly outside resolver

## UI Data Contract Requirements

The renderer must be able to read, per side:
- points, mult, total
- energy current/max
- money (player only visible)
- pose lists
- pouch count
- deck/discard/hand counts
- hand card list
- playable stones list
- selected stone

Message board reads:
- head item in `message_queue`
- optional backlog for recent events

UI visibility rule:
- player deck summary is shown at bottom-right
- opponent deck details are hidden in MVP UI

## Determinism Requirements

For repeatable tests:
- all random draws must come from a seeded RNG source
- resolver event order must not depend on table iteration order
- illegal actions produce no partial state mutation

