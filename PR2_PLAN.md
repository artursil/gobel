# PR 2 - Unified Object Schemas

## Scope

Standardize all object definitions (stones, cards, stances) with unified metadata schema and move canonical definitions to `objects/`.

## Done Criteria (from PR_MILESTONES.md)

- All three object types load from `objects/*`
- Effect schema is consistent and validated

## Key Tasks

### 1. Unified Metadata Schema

**Current state:**
- Stones have: `id`, `name`, `description`, `depiction`, `graphic`, `effects`
- Cards have: `id`, `name`, `description`, `display_name`, `energy_cost`, `effects`
- Stances have: `id`, `display_name`, `trigger`, `effects`

**Target state (add to all):**
- `id` ✓ (already have)
- `name` ✓ (have for stones/cards, need for stances)
- `description` ✓ (have for stones/cards, need for stances)
- `type` - NEW (classification: "stone", "card", "stance")
- `rarity` - NEW (optional, defaults to "common")
- `probability` - NEW (optional, defaults to 1.0)

### 2. Unified Effect Schema

**Current state:**
- All effects use: `effect_name`, `phase`, `value`, `priority`
- Some have `duration`, `scope`, `conditions` (not yet)

**Target state (standardize):**
- `effect_name` ✓ (required)
- `phase` ✓ (required)
- `value` or `params` ✓ (has value)
- `priority` ✓ (required)
- `duration` - NEW (optional, for timed effects)
- `scope` - NEW (optional: "self", "board", "hand", etc.)
- `conditions` - NEW (optional: array of condition checks)

### 3. Move Definitions to `objects/`

**Already done:**
- ✓ `objects/definitions/stones.lua`
- ✓ `objects/definitions/stances.lua`
- ✓ `objects/definitions/cards.lua`

**Need to do:**
- Remove compat shims from old locations (PR 1 cleanup)
- Consolidate definitions into unified format
- Add missing metadata fields

### 4. Validation & Schema Enforcement

**Add schema validator:**
- Function to validate object definitions at load time
- Check required fields present and correct type
- Check effect entries conform to schema
- Warn or error on missing optional fields

## Implementation Plan

### Phase 1: Add Metadata Fields
1. Add `type` field to all object definitions
2. Add `rarity` field (optional) to all
3. Add `probability` field (optional) to all
4. Update stances to have `name` and `description` (not just `display_name`)

### Phase 2: Standardize Effects
1. Audit all effect entries for consistency
2. Add `duration` where needed
3. Add `scope` where needed
4. Prepare `conditions` structure (may be implemented in PR 3)

### Phase 3: Schema Validation
1. Create `objects/schema.lua` with validators
2. Call validators at definition load time in `content.lua`
3. Log or error on schema violations

### Phase 4: Cleanup
1. Remove compat shims
2. Update imports to use `objects/` directly
3. Verify all tests pass

## Files to Modify

### Definitions
- `objects/definitions/stones.lua`
- `objects/definitions/stances.lua`
- `objects/definitions/cards.lua`

### Schema & Validation
- `objects/schema.lua` (NEW)
- `objects/definitions.lua` (NEW - unified loader)

### Loaders
- `content.lua` - add schema validation

### Cleanup
- Remove old compat shims:
  - `poses/definitions.lua` (delete)
  - `poses/effects.lua` (delete)

## Testing Strategy

- Update existing tests to validate new metadata
- Add schema validation tests
- Verify all objects conform to schema
- No behavior changes - tests should pass with updated assertions

## Risk Assessment

**Low Risk:**
- Adding optional metadata fields (backward compatible)
- Schema validation is informational (warnings only initially)
- No effect logic changes, only structure

**Mitigation:**
- Schema validation can warn before erroring
- Compat layer remains during transition
- All tests run to verify no behavioral changes

## Success Metrics

✓ All objects have complete metadata (required + optional fields)
✓ All effects follow unified schema
✓ Schema validator runs at load time
✓ All tests pass
✓ No behavior changes observed

---

## Next Steps After PR 2

PR 3 will:
- Implement effects/conditions engine in `objects/effects.lua`
- Add condition evaluation system
- Move all business logic from resolvers to effects
