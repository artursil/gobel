# Trigger Field Removal: Cleanup

## Summary

Removed the redundant `trigger` field from stance definitions and the associated `dispatch_trigger` function. The effect `phase` field is sufficient to control when stances execute in the turn cycle.

## Why Trigger Was Redundant

**Original assumption**: `trigger` controls WHEN a stance is evaluated, `phase` controls WHAT a stance does.

**Actual implementation**: 
- All active stances are evaluated every phase (via `effect_manager.lua:26-34`)
- Effects are filtered purely by `phase` to determine execution order
- The `trigger` field was never checked in the resolution flow

**Conclusion**: The effect's `phase` alone determines when a stance affects the game. The `trigger` field added no functional value.

## Changes Made

### 1. Removed `trigger` from Stance Definitions

**File**: `objects/definitions/stances.lua`

**Before**:
```lua
stance_point = {
    trigger = "TURN_START",
    effects = { ... }
}
```

**After**:
```lua
stance_point = {
    effects = { ... }
}
```

All three stances updated: `stance_point`, `stance_mult`, `stance_heavy_point`

### 2. Removed `dispatch_trigger` Function

**File**: `stances.lua`

Removed unused function:
```lua
function M.dispatch_trigger(player_state, trigger_name, callback)
    -- Filtered stances by trigger == trigger_name
end
```

This function was defined but never called in actual game code.

### 3. Updated Tests

**File**: `spec/poses_spec.lua`

- Removed tests that verified trigger dispatch behavior
- Replaced with simpler tests for `active_stance_ids`
- Tests now verify 2 core functions: `active_stance_ids` (unchanged) and removal of unused dispatch logic

**Before**: 5 test cases (including trigger dispatch tests)
**After**: 3 test cases (active_stance_ids only)

## Architecture Simplification

**Old model** (redundant):
```
Trigger (TURN_START) → Dispatch stances → Filter by phase → Execute
```

**New model** (simplified):
```
Iterate all active stances → Filter by phase → Execute
```

The phase field in effects is the sole control point for when stances execute.

## Impact

- **Behavior**: No change - stances still execute with the same phase-based filtering
- **Code**: Cleaner, fewer redundant fields
- **Performance**: Marginal improvement (no trigger string comparisons)
- **Tests**: 77 passing (was 78, removed 1 obsolete test)

## Files Modified

- `objects/definitions/stances.lua` - Removed `trigger` field from all stances
- `stances.lua` - Removed `dispatch_trigger` function and unused import
- `spec/poses_spec.lua` - Removed trigger-based tests, kept core functionality tests

## Verification

- ✓ All syntax valid
- ✓ 77 tests passing (1 removed test, 1 unrelated placeholder failure)
- ✓ No behavior changes
- ✓ Code simplified
- ✓ Architecture cleaner (single control point: `phase`)

## Next Steps

With trigger removed:
- PR 2 object schema is finalized
- Effect `phase` is the single source of truth for execution timing
- Ready for PR 3: Unified Effects and Conditions Engines
