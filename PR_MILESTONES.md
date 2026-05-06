# PR_MILESTONES.md

## Purpose

Track the staged refactor toward a unified, state-driven effects/conditions architecture.

Core rule:
- All gameplay logic must live in `objects/effects.lua` and `objects/conditions.lua`.
- `run_state` and `game_state` are the only logic entry points.
- Resolver modules orchestrate phase order and dispatch only.

---

## PR 1 - Rename and Structure Baseline

### Scope
- Rename `poses` to `stances` across runtime, data fields, and references.
- Create `objects/` directory with:
  - `objects/stones.lua`
  - `objects/cards.lua`
  - `objects/stances.lua`
  - `objects/effects.lua`
  - `objects/conditions.lua`
- Add temporary compatibility aliases only where required.

### Done Criteria
- No active runtime path depends on `pose*` naming.
- Game boots and existing tests still pass.

---

## PR 2 - Unified Object Schemas

### Scope
- Move canonical definitions into `objects/*`.
- Standardize shared metadata across stones/cards/stances:
  - `id`, `name`, `description`, `type`, `rarity`, `probability`
- Standardize effect entries:
  - `effect_name`, `phase`, `value`/`params`, `priority`, `duration`, `scope`, `conditions`

### Done Criteria
- All three object types load from `objects/*`.
- Effect schema is consistent and validated.

---

## PR 3 - Unified Effects and Conditions Engines

### Scope
- Implement `objects/effects.lua` as single effect operation registry.
- Implement `objects/conditions.lua` as single condition operation registry.
- Add generic condition evaluation over:
  - `run_state`
  - `game_state`
  - `action_context`

### Done Criteria
- Resolver no longer contains feature-specific rule logic.
- Effects execute through registry dispatch only.

---

## PR 4-6 Combined - State Architecture + Phases + Resolver Adaptation

### Scope
- Refactor in one integrated pass:
  1. Define explicit `run_state` and `game_state` contracts.
  2. Define and enforce the new phase model (including `distance`).
  3. Adapt resolver to pure orchestration over effects/conditions.
- Introduce new folders and migration targets:
  - `single_game/`
  - `single_run/`
  - move `resolver/` under `single_game/resolver/`
- Add schema files (kept separate, required for implementation):
  - `single_game/game_state.schema.md`
  - `single_game/player_game_state.schema.md`
  - `single_run/run_state.schema.md`
  - `single_game/resolver/ObjectInstance.schema.md`
  - `single_game/resolver/Effect.schema.md`
  - `single_game/resolver/Condition.schema.md`
- State-first implementation order:
  - create states and schema contracts first
  - define final phase ordering second
  - adapt resolver third
  - keep compatibility adapters until migration complete

### Done Criteria
- `run_state` and `game_state` are fully defined and used as resolution entry points.
- Effects/conditions resolve exclusively from state + context.
- No phase inference from ad-hoc payload logic.
- Territory-distance interactions are phase-driven.
- Resolver is orchestration-only:
  1. build phase context
  2. collect candidate effects
  3. evaluate conditions
  4. resolve probabilities
  5. apply effects in priority order
- No object-specific branching in resolver loops.
- Baseline gameplay parity maintained.

---

## PR 7 - Object Instance Mutability

### Scope
- Introduce object instance model:
  - `instance_id`, `def_id`, `level`, `modifiers`, `extra_effects`, status fields
- Support runtime add/remove/disable/destroy/evolve operations.
- Support hidden persistent objects ("fake stances") for lingering card effects.

### Done Criteria
- Effects can modify object behavior through instance state without resolver changes.

---

## PR 8 - Probability and Defense Framework

### Scope
- Add shared probability resolver using keyed RNG streams.
- Include defense scaling in chance computations.
- Example rule support:
  - base `1/4` with defense `2` becomes `1/8`.
- Implement per-key RNG as `seed + key + calls` (no mutable stream state field).

### Done Criteria
- Chance-based effects use one shared probability path.
- RNG behavior is deterministic and replayable by key.

---

## PR 9 - Vertical Proof Feature

### Scope
- Implement one full conditional + phased feature using only:
  - object definitions
  - effects
  - conditions
  - run/game state
- Example class:
  - points gain gated by prisoner condition
  - distance-phase modifier consumed by territory computation

### Done Criteria
- No special-case resolver logic added for the feature.
- Deterministic tests cover success and failure paths.

---

## Quality Rules for Every PR

- Small, focused functions with one responsibility.
- Clear docstrings for public and non-trivial private functions.
- Typed Lua annotations for params/returns and key table shapes.
- Avoid deep nesting; prefer guard clauses.
- No duplicate logic; extract shared helpers.
- Keep behavior deterministic and ordering explicit.
- Document temporary compatibility shims and removal plan.
- Include/update tests with each PR.

---

## Review Checklist

Before merging any milestone PR, confirm:
- Business logic is only in `objects/effects.lua` and `objects/conditions.lua`.
- Resolver remains orchestration-only.
- State contract changes are explicit and documented.
- No hidden side effects outside state mutation paths.
- Tests cover introduced behavior and ordering guarantees.

---

## Schema References (Required)

Code writer must follow these schema files as contracts:
- `single_game/game_state.schema.md`
- `single_game/player_game_state.schema.md`
- `single_run/run_state.schema.md`
- `single_game/resolver/ObjectInstance.schema.md`
- `single_game/resolver/Effect.schema.md`
- `single_game/resolver/Condition.schema.md`

If runtime implementation differs from schema, update schema first, then code.

---

## Per-Key RNG Contract

Use counter-based RNG streams with no mutable per-stream `state` field.

### Required inputs
- `base_seed` (run-level immutable seed)
- `key` (stream name, e.g. `draw.cards.player`)
- `calls` (how many times the stream has been consumed)

### Required behavior
- random output = deterministic function of `(base_seed, key, calls)`
- on consume:
  - read `calls`
  - compute output
  - increment `calls` by 1

### Why this model
- deterministic replay by stream
- no hidden mutable RNG state blobs
- easy debugging (`what was call #17 of stream X?`)

### Minimal run-state shape for RNG
```lua
seed = {
  base_seed = 123456789,
  streams = {
    ["draw.cards.player"] = { calls = 0 },
    ["draw.stones.player"] = { calls = 0 },
    ["effect.destroy_stone"] = { calls = 0 },
    ["shop.roll"] = { calls = 0 },
  },
}
```
