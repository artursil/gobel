# Gobel — domain glossary

Canonical terms for stone effects architecture. Normative detail: `docs/effects-architecture.md`, [ADR 0001](docs/adr/0001-stone-effects-stages-and-phases.md).

## Effect

Object behavior on a definition: `effect_name` + **`action`** + `phase`, optional `conditions`. One object can have **many effect rows** (e.g. `on_play`, `tick`, `end_of_turn`, `on_removed`). Each resolves to **`apply` only** — no other hooks on the resolved table. Implementation: `objects/effects_conditions/effects/<effect_name>.lua`.

## Action

Which match beat invokes the effect. Canonical values (enum): `game_start`, `before_turn`, `on_card`, `on_play`, `end_of_turn`, `tick`, `on_removed`, `game_end`.

## Phase

Which scoring pass runs the effect: `territory`, `points`, or `mult`. Order within a beat is always territory → points → mult.

## Resolver stage

Generic pipeline module under `single_game/resolver/stages/`. Updates board or legality without object-specific `if kind ==` branches.

## On-play pipeline

After a stone is committed: (1) commit board → (2) remove stones → (3) territory phase → (4) points phase → (5) mult phase → (6) recalculate legal moves. Lives under `single_game/resolver/stages/`; `resolver.lua` is only the action API (submit, validate, events).

## Remove stones stage

On-play step 2. Captures, sacrifice/self-removal, expiry; awards capture points. Not an effect hook.

## Legality of moves

Final on-play step. Refreshes cached legal placements from board, immunity, blockade, ko. Immunity and similar checks use helpers from `stages_helpers/` (e.g. anti-capture condition) — not effect hooks.

## Anti-capture immunity

`on_play` effect sets `duration_left` on the cell (from parameters via def). Generic tick stage decrements it. Legality reads the field via `stages_helpers/anti_capture.lua`.

## Stages helpers

Pure legality/board-query helpers used by stages (`stages_helpers/`). Example: anti-capture condition for legal moves. Not effects — no scoring, no state mutation beyond what the stage orchestrates.

## Placement record

`round_stone_effects` / placement context for the current play. Phased `apply` uses this when the stone is removed before the points phase (e.g. kamikaze).

## Duration left

Unified countdown: **`cell.duration_left`** on placed stones; **`instance.duration.remaining_rounds`** on ObjectInstances. Generic stage decrements. Timed stones use separate effect rows with **`action = tick`** (and `on_play` setup); each row has **`apply` only**.

## Defence network

When a defence stone is played (`on_play`), it adds solidity once to itself and connected friendly stones. The buff is permanent — nothing recalculates when stones are later captured or removed.

When any stone is played next to an already-placed defence stone, that new stone also gets the defence solidity buff. Cross-stone buffs like this are declared in `shared_stones_effects` so every stone picks them up without copy-paste.

## Shared stone effects

Reusable effect definitions applied to all stones (or a broad class) — e.g. pattern mult bonuses, defence-adjacency buffs. Declared once in `objects/definitions/shared_stones_effects.lua`; the resolver applies them during board scan or on-play as appropriate.

## Selected board target

Board cell the player picked when playing a targeting card (`selected_targets` / `selected_target` on the card-play event). Copied into resolution metadata before `apply`. Card effects that damage, heal, destroy, or buff a stone read this via shared helpers — **not** via condition kwargs.

Distinct from **selected hand stone** (`player.stones.selected_stone`): the stone kind/index chosen for the next placement, not a board target.

## Condition

Each `condition_name` has its own file: `objects/effects_conditions/conditions/<condition_name>.lua` — detailed module docstring at top, `eval` as first function. Registry `conditions.lua` routes `M.eval` by name. Return shape: **`pass, kwargs_fragment | nil`**. Params on the condition row (`value`, `probability`, `tag`) are read from `condition_def` inside `eval`.

For selected-board-target cards, conditions are **gate-only** (pass/fail). They do not pass row/col into kwargs; the effect reads the target from resolution state.

## Effect apply

Every effect `apply` uses **`(state, owner, kwargs)`**. **`kwargs` is only what conditions returned** at runtime. Numeric fields on the effect row (`value`, `rounds`, `duration`, `payout`, …) come from **`objects/parameters/*`** via the definition — read in `build` closure, passed to helpers; not hardcoded in effect files.

The second argument to `apply` is always **effect owner** (`"B"` / `"W"`) for that resolve pass — the same owner `effect_manager` already attaches to collected effects. Placement coordinates and removal context are read inside helpers from `state`, the placement record, or resolution metadata.

## Effect schema

Validates the shape of an effect definition (`effect_name`, `action`, `phase`, optional fields). Lives in `objects/effects_conditions/`; not part of the resolver.

## Condition schema

Validates the shape of a condition definition (`condition_name`, params). Lives in `objects/effects_conditions/`; not part of the resolver.

## Effects–conditions module

Shared home under `objects/effects_conditions/` for effect and condition dispatch, schemas, scheduling (enums, parse, factory), and the runner that evaluates conditions and calls `apply(state, owner, kwargs)`.

Helpers are split: per-name files under `effects/` and `conditions/` (overview + main function), reusable math in `helpers/shared/`. Module invariants: `objects/effects_conditions/CONTEXT.md`.

## Tick step

At end of turn, one generic stage subtracts 1 from every timer field on the board (stones and other objects). It does not interpret what each timer means. Expired stones are removed in the remove-stones step; timer side effects (immunity fading, blockade shrinking) run via effects with `action = tick`.

## Removal effects dispatch

When a stone leaves the board, `on_removed` effects run only because the code that removed it says so — not because the board is secretly watched. Every removal path (capture, timer expiry, card, sacrifice) must call the removal-effects step explicitly.

**Sacrifice is not removal.** When a stone removes itself as part of play (e.g. kamikaze), `on_removed` effects do not run — only its `on_play` effects do.

## Navigation rule

Scoring: object def → `effects/<effect_name>.lua` → runner → `conditions/<condition_name>.lua`. Shared math: `helpers/shared/`. Board rules: `resolver/stages/`.
