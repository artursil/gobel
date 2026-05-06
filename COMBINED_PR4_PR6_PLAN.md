# Combined PR4-PR6: Integrated State & Resolver Refactor

## Scope

Combine PR4 (State Architecture), PR5 (Phase Model), and PR6 (Resolver Adaptation) into one integrated refactor using explicit schema contracts.

## Critical Requirements

1. **Schema-backed runtime**: Schemas are not documentation. All state must conform at runtime.
2. **Folder migration**: Move resolver to `single_game/resolver/`
3. **RNG implementation**: Per-key deterministic RNG using (base_seed, key, calls)
4. **Resolver migration**: Move and refactor to orchestration-only
5. **No dead docs**: Schemas drive implementation

## Implementation Order

### Phase 1: Create Folder Structure & Base State

Create:
- `single_run/run_state.lua` - Runtime run_state constructor
- `single_game/game_state.lua` - Runtime game_state constructor
- `single_game/player_game_state.lua` - Runtime PlayerGameState constructor

Must conform to schema files.

### Phase 2: RNG Manager

Implement per-key deterministic RNG:
- `single_run/rng.lua` - RNG manager with (base_seed, key, calls) contract
- Expose: `next_float(run_state, key)`, `next_int(run_state, key, n)`
- Deterministic: same seed/key/calls always produces same value

### Phase 3: ObjectInstance Runtime

Implement:
- `single_game/resolver/ObjectInstance.lua` - Constructor and helpers
- Conform to ObjectInstance schema
- Instance tracking via instance_id

### Phase 4: Effect/Condition Schemas

Implement:
- `single_game/resolver/Effect.lua` - Effect handling
- `single_game/resolver/Condition.lua` - Condition evaluation
- Ensure both use new state contracts

### Phase 5: Resolver Migration

Move resolver modules to `single_game/resolver/`:
- Refactor to orchestration-only
- Wire to new state contracts
- Enforce phase model

### Phase 6: Adapters & Testing

- Create minimal backward compat adapters
- Run all tests
- Verify no regression

## Files to Create

**Folder structure:**
```
single_run/
  run_state.schema.md (existing)
  run_state.lua (NEW)
  rng.lua (NEW)

single_game/
  game_state.schema.md (existing)
  player_game_state.schema.md (existing)
  game_state.lua (NEW)
  player_game_state.lua (NEW)
  
  resolver/
    ObjectInstance.schema.md (existing)
    Effect.schema.md (existing)
    Condition.schema.md (existing)
    ObjectInstance.lua (NEW)
    Effect.lua (move/refactor from objects/effects.lua)
    Condition.lua (move/refactor from objects/conditions.lua)
    resolve_round.lua (move/refactor from resolver/)
    effect_manager.lua (move/refactor from resolver/)
    territory.lua (move/refactor from resolver/)
```

## Success Criteria

✓ Runtime states conform to all 6 schema files
✓ Per-key RNG deterministic with (base_seed, key, calls)
✓ Resolver migrated to single_game/resolver/
✓ Resolver orchestration-only (no feature logic)
✓ All 110+ tests pass
✓ No regression in gameplay
✓ Minimal, documented adapters only
