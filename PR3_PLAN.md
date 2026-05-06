# PR 3 - Unified Effects and Conditions Engines

## Scope (from PR_MILESTONES.md)

- Implement `objects/effects.lua` as single effect operation registry
- Implement `objects/conditions.lua` as single condition operation registry
- Add generic condition evaluation over: `run_state`, `game_state`, `action_context`

## Done Criteria

- ✓ Resolver no longer contains feature-specific rule logic
- ✓ Effects execute through registry dispatch only

## Current State Analysis

### objects/effects.lua

**Status**: Partially implemented
- ✓ Basic effect builders: `add_points`, `add_mult`, `distance_bonus`
- ✓ Board stone effect handler: `resolve_board_stone`
- ✓ Generic `resolve(effect)` dispatcher
- ✓ Board effect builders registry structure

**Gaps**:
- No condition evaluation integrated
- No scope-based filtering (self, board, opponent, all)
- No duration/timed effect management
- Limited effect types (only points, mult, distance_bonus implemented)

### objects/conditions.lua

**Status**: Stub only
- Only placeholder: `eval(condition_name, state, context)` returns `true`
- No condition implementations
- No integration with effect system

### effect_registry.lua

**Status**: Acts as dispatcher
- ✓ Routes to `objects/effects.lua`
- ✓ Handles stance/card/stone effect resolution
- ⚠ Still contains compat alias `M.poses` (unused, should remove)

### Resolver modules

**Status**: Still contains some feature logic
- `resolver/effect_manager.lua` - Orchestrates effect collection and application
- `resolver/resolve_round.lua` - Phase execution loop

## PR 3 Implementation Plan

### Phase 1: Remove Compat Aliases

Files:
- `effect_registry.lua` - Remove `M.poses` compat alias

### Phase 2: Expand Effect System

Add missing effect builders to `objects/effects.lua`:
- Condition-gated effects framework
- Duration/timed effects support
- Scope-based effect application (self, board, opponent, all)
- Error handling for unknown effects

### Phase 3: Implement Conditions Engine

Implement `objects/conditions.lua`:
- Condition evaluation registry (dispatcher pattern like effects)
- Built-in condition types:
  - `always` - Always true
  - `never` - Always false
  - `random` - Based on probability
  - Future: `turn_number_matches`, `card_in_hand`, etc.
- Integration with effect system (conditions gate effect application)

### Phase 4: Integrate Conditions into Effects

Update effect resolution flow:
- Each effect can have optional `conditions` array
- During effect application, evaluate all conditions
- Only apply effect if all conditions pass
- Support condition context (state, action_context)

### Phase 5: Verify Resolver Uses Registry

Ensure `resolver/effect_manager.lua`:
- Uses `effect_registry` for all effect resolution
- No feature-specific branching in loops
- Calls effect `apply` functions through registry

### Phase 6: Add Tests

Update/add tests:
- `spec/effects_spec.lua` - Test all built-in effect types
- `spec/conditions_spec.lua` - Test condition evaluation
- `spec/effect_conditions_integration_spec.lua` - Test conditions gating effects

## Key Architecture Decisions

1. **Effect dispatch pattern**: Existing `objects_effects[effect_name](effect)` pattern is solid - keep it
2. **Condition evaluation**: Similar dispatcher - `objects_conditions[condition_name](context)` pattern
3. **Composition**: Effects can contain conditions array; resolver evaluates before applying
4. **Error handling**: Log unknown effects/conditions, return gracefully (don't break game)

## Success Metrics

✓ No feature-specific rule logic in resolver loops
✓ All effects go through `objects/effects.lua` registry
✓ All conditions go through `objects/conditions.lua` registry
✓ Conditions can gate effect application
✓ Tests cover effect and condition evaluation
✓ No compat aliases remain

## Dependencies & Risks

- **Risk**: Changing effect application flow might break existing stones/cards/stances
- **Mitigation**: Comprehensive test coverage for existing effect types
- **Dependency**: Conditions system must work with current score-based system

## Files to Modify

Core:
- `objects/effects.lua` - Expand with more effect types and condition support
- `objects/conditions.lua` - Implement full condition registry
- `effect_registry.lua` - Remove compat aliases
- `resolver/effect_manager.lua` - Verify no feature logic (no changes needed if clean)

Tests:
- `spec/effects_spec.lua` (new or update)
- `spec/conditions_spec.lua` (new)
- `spec/effect_conditions_integration_spec.lua` (new)

## Not in PR 3 Scope

- State architecture (PR 4)
- Phase model redesign (PR 5)
- Resolver refactoring (PR 6)
- Object instance model (PR 7)
- Probability framework (PR 8)

---

## Next Steps After PR 3

PR 4 will:
- Introduce explicit `run_state` and `game_state` contracts
- Add per-key RNG manager
- Expand state fields for inventory, modifiers, usage counters
- Enable effects/conditions to resolve exclusively from state + context
