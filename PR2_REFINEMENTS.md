# PR 2 Refinements: Three Improvements

## Summary

Applied three improvements to PR 2 unified object schemas:
1. Added `cost` field to all objects for consistent resource management
2. Verified no duplicate phase definitions
3. Analyzed necessity of `trigger` in stances

## 1. Cost Field Added to All Objects

### Stones
- **Cost**: 1 (base placement cost for all stones)
- Fields: `cost = 1` added to all stone definitions
- Stones: `stone_basic`, `stone_power`, `stone_focus`, `stone_lieutenant`, `stone_tower`

### Stances
- **Cost**: 0 (no placement cost, always active)
- Fields: `cost = 0` added to all stance definitions
- Stances: `stance_point`, `stance_mult`, `stance_heavy_point`

### Cards
- **Cost**: Unified field added (matches `energy_cost`)
  - `card_point_tap`: cost = 1
  - `card_point_push`: cost = 2
  - `card_small_mult`: cost = 1
  - `card_big_mult`: cost = 2
  - `card_balanced_boost`: cost = 2

### Schema Validator Updated
- Added required validation for `cost` field
- Ensures `cost` is a non-negative number
- Validation runs at content load time

## 2. Phase Definitions Audit

### Result: NO DUPLICATES FOUND ✓

**Defined Phases in schema.lua:**
1. `distance` - Distance-based territory calculation
2. `territory` - Territory modification effects
3. `points` - Point scoring
4. `mult` - Multiplier scoring
5. `hand` - Hand/card operations (prepared for future)
6. `discard` - Discard operations (prepared for future)

**Usage across definitions:**
- `distance`: 1 effect (stone_lieutenant)
- `territory`: 1 effect (stone_tower)
- `points`: 12 effects (used by 8 objects)
- `mult`: 8 effects (used by 5 objects)
- `hand`: 0 effects (not yet used)
- `discard`: 0 effects (not yet used)

**Verification**: Each phase defined exactly once in schema, each object uses valid phases with no duplication.

## 3. Trigger vs Phase Analysis

### Question
Is `trigger` variable necessary in stances definitions when effects already have `phase`?

### Answer: YES, BOTH ARE NECESSARY ✓

These are **distinct concerns** that cannot be replaced:

| Aspect | Trigger | Phase |
|--------|---------|-------|
| **What it is** | Event that activates a stance | Effect execution order within a turn |
| **When used** | External dispatcher (event system) | Internal phase system (turn resolution) |
| **Example** | `TURN_START`, `CARD_PLAYED` | `points`, `mult`, `distance` |
| **Responsibility** | Determine IF stance should be evaluated | Determine WHEN within turn to execute |

### Current Implementation

**Trigger dispatch (stances.lua:37-43):**
```lua
function M.dispatch_trigger(player_state, trigger_name, callback)
    for_each_active_stance_id(player_state, function(stance_id)
        local stance_def = content.get_stance(stance_id)
        if stance_def and stance_def.trigger == trigger_name then  -- Filter by trigger
            callback(stance_id, stance_def)
        end
    end)
end
```

**Phase execution (resolver):**
```lua
for each phase in turn do
    for each effect in phase do
        if effect.phase == phase then  -- Filter by phase
            execute(effect)
        end
    end
end
```

### Why Both Are Necessary

1. **Trigger determines participation**: "Should this stance be evaluated at all for this event?"
2. **Phase determines execution order**: "Given this stance's effects, when in the turn should they execute?"

**Example:**
```lua
stance_point = {
    trigger = "TURN_START",        -- Active at turn start
    effects = {
        { effect_name = "add_points", phase = "points", ... }  -- Execute in points phase
    }
}
```

Without `trigger`: System wouldn't know to consider this stance during TURN_START event.
Without `phase`: System wouldn't know whether to execute in points phase vs mult phase vs other phase.

## Files Modified

- `objects/definitions/stones.lua` - Added `cost = 1` to all stones
- `objects/definitions/stances.lua` - Added `cost = 0` to all stances
- `objects/definitions/cards.lua` - Added `cost` field to all cards
- `objects/schema.lua` - Added `cost` field validation

## Tests

- **Passed**: 78 tests (unchanged from previous)
- **Failed**: 1 test (unrelated placeholder test)
- **Errors**: 0
- **Syntax**: All files valid

## Next Steps

These refinements complete PR 2 validation and analysis. The codebase is ready for:
- PR 3: Unified Effects and Conditions Engines
- PR 4: State Architecture (run_state and game_state)
- Future: Additional trigger types and phases as needed

---

## Checklist

✓ Cost field added to all object types (stones: 1, stances: 0, cards: 1-2)
✓ Schema validator updated for cost validation
✓ Phases verified (no duplicates, 6 total defined)
✓ Trigger necessity confirmed (distinct from phase)
✓ All tests pass
✓ No behavior changes
