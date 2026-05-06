# PR 4 - State Architecture First

## Scope (from PR_MILESTONES.md)

- Introduce explicit `run_state` and `game_state` contracts
- Add per-key RNG manager to `run_state` with deterministic substreams
- Add state fields needed for current + planned effects:
  - inventory and object instances
  - played/discarded/remaining tracking
  - temporary/permanent modifiers
  - disable/destroy/evolution/usage counters
  - prediction and sequence state

## Done Criteria

- Effects and conditions can resolve exclusively from state + context
- Legacy behavior preserved via adapters where needed

## Current State Analysis

### Existing State Structure

Current state fields (from grep):
- `state.scores` - Player scores (turn_bonus, territory, points, plus_mult, x_mult, total)
- `state.stones` - Player stone inventories
- `state.stances` - Player active stances
- `state.modifiers` - Cards in play (modifiers array)
- `state.board` - 9x9 game board
- `state.round_stone_effects` - Effects from stone placements in current action
- `state.active_effects` - Timed effects (duration tracking)
- `state.territory_value` - Territory value matrix
- `state.distance_modifiers` - Distance bonuses by stone
- Various UI state fields (phase, mode, focus_index, etc.)

### Issues with Current Structure

1. **Mixed concerns**: Game logic + UI state in same object
2. **No clear contracts**: Effect/condition code unclear what state fields are available
3. **No RNG isolation**: RNG in match_state, not accessible from effects
4. **No instance tracking**: Can't track object instances (id, mods, status)
5. **No inventory system**: Objects tracked by ID only, not instances
6. **No modifiers tracking**: Can't track temporary/permanent mods on objects

## PR 4 Architecture

### run_state Contract

**Purpose**: Minimal game logic state
**Content**:
- board configuration (size)
- player identifiers (black, white)
- turn counter
- phase counter
- RNG manager (per-key streams)
- seed state

**Use**: Pure game logic (effects, conditions, resolvers)

### game_state Contract

**Purpose**: Complete game state for serialization and determinism
**Content**: All of run_state + UI/display state
- UI focus
- message queue
- animation state
- etc.

### State Field Organization

#### Inventory (Object Instances)

```lua
state.inventory = {
    black = {
        stones = {
            { id = "stone_1", def_id = "stone_basic", modifiers = {} },
            { id = "stone_2", def_id = "stone_power", disabled = false },
        },
        stances = {
            { id = "stance_1", def_id = "stance_point", modifiers = {} },
        },
        cards = {
            { id = "card_1", def_id = "card_point_tap", in_hand = true },
        },
    },
    white = { ... },
}
```

#### Tracking

```lua
state.tracking = {
    black = {
        stones = {
            played_count = 0,
            remaining_count = 20,
            discarded = {},
        },
        cards = {
            played_count = 0,
            discarded_count = 0,
            deck_remaining = 10,
        },
    },
    white = { ... },
}
```

#### Modifiers

```lua
state.modifiers = {
    temporary = {
        -- One-turn effects
        { target_id = "stone_1", effect = "extra_points", value = 2 },
    },
    permanent = {
        -- Multi-turn effects
        { target_id = "stone_2", effect = "damage_reduced", value = 1 },
    },
}
```

#### Object Status

```lua
state.object_status = {
    stone_1 = { disabled = false, destroyed = false, level = 1 },
    stance_1 = { active = true, hidden = false },
    card_1 = { used = false, charges = 3 },
}
```

### RNG Manager

```lua
state.rng = {
    seed = 12345,
    streams = {
        distance_calc = { seed = 12345 },
        card_draw = { seed = 23456 },
        combat = { seed = 34567 },
        -- etc.
    },
    next_int = function(stream_key, max_value) ... end,
}
```

## Implementation Plan

### Phase 1: Define Contracts

Create:
- `objects/run_state.lua` - run_state contract and helpers
- `objects/game_state.lua` - game_state contract and helpers

### Phase 2: RNG Manager

Implement per-key RNG in run_state:
- Deterministic substreams by key
- Seeded initialization
- Accessor function `state.rng:next_int(stream_key, max_value)`

### Phase 3: Inventory System

Refactor current stone/stance/card tracking:
- Convert from ID arrays to instance objects
- Add instance_id, def_id, modifiers, status fields
- Accessor helpers for inventory queries

### Phase 4: Modifier Tracking

Add temporary/permanent modifier tracking:
- Separate from "modifiers" (which is currently cards in play)
- Per-object modifier application
- Duration tracking for temporary mods

### Phase 5: Migrate State Usage

Update callers:
- Adapt current state.stones to new inventory format
- Adapt state.modifiers (cards) - rename to avoid confusion
- Update effect/condition code to use new state structure

### Phase 6: Adapter Layer

For backward compatibility:
- Create adapters from old state structure to new
- Mark as temporary (to be removed in PR 5+)

## Files to Create

- `objects/run_state.lua` - run_state contract
- `objects/game_state.lua` - game_state contract
- `objects/rng_manager.lua` - Per-key RNG implementation

## Files to Modify

- `match_state.lua` - Initialize new state structure
- Effect/condition code - Adapt to use new state fields
- Resolver code - Adapt to new state structure

## Not in PR 4 Scope

- UI state separation (leave UI state in game_state for now)
- Effect prediction system (prepare structure, implement in PR 5+)
- Object evolution/leveling system (prepare structure, implement in PR 7+)

## Success Metrics

✓ run_state and game_state contracts defined
✓ Per-key RNG manager with deterministic substreams
✓ Inventory system with object instances
✓ Modifier tracking (temporary/permanent)
✓ Object status tracking
✓ All tests still pass
✓ No behavior changes
✓ Effects can resolve exclusively from state + context

## Risks

- **Large refactor**: Significant state structure changes
- **Backward compat**: Need adapters for legacy code
- **Test failures**: State structure changes will break tests

## Mitigation

- Implement adapters for backward compatibility
- Comprehensive test updates
- Phase implementation (RNG first, then inventory, etc.)



Now I want to understand that all of the changes we made so far meet my expectations therefore I want you to show me 2 things
1. How would you add a stance that does following - when we just added stone type special on the board we multiply x_mult 1.5X for each card type steel that we hold in the hand. Please without changing code show me exactly in which files what changes you would need to do.
2. Then explain me file by file how in code this thing is resolved, what scripts are used, show me entire pipeline for this effect
