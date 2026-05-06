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

## PR 4 - State Architecture First (Before Resolver Migration)

### Scope
- Introduce explicit `run_state` and `game_state` contracts.
- Add per-key RNG manager to `run_state` with deterministic substreams.
- Add state fields needed for current + planned effects:
  - inventory and object instances
  - played/discarded/remaining tracking
  - temporary/permanent modifiers
  - disable/destroy/evolution/usage counters
  - prediction and sequence state

### Done Criteria
- Effects and conditions can resolve exclusively from state + context.
- Legacy behavior preserved via adapters where needed.

---

## PR 5 - Phase Model Redesign

### Scope
- Define and enforce the new phase model (including `distance`).
- Validate each effect references a legal phase.
- Document phase order and trigger windows.

### Done Criteria
- No phase inference from ad-hoc payload logic.
- Territory-distance interactions are phase-driven.

---

## PR 6 - Resolver Adaptation

### Scope
- Refactor resolver to pure orchestration:
  1. build phase context
  2. collect candidate effects
  3. evaluate conditions
  4. resolve probabilities
  5. apply effects in priority order
- Territory computation must consume prepared effect-driven state.

### Done Criteria
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

### Done Criteria
- Chance-based effects use one shared probability path.

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
