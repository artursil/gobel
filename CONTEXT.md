# Gobel — domain glossary

Canonical terms for stone effects architecture. Normative detail: `docs/effects-architecture.md`, [ADR 0001](docs/adr/0001-stone-effects-stages-and-phases.md).

## Effect

Object behavior on a definition: `effect_name` + `action` + `phase`, optional `conditions`. Exposes **`apply` only** (no placement hooks).

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

`on_play` effect sets `immunity_remaining` on the cell. `tick` effect counts it down. The legality stage reads that field via `stages_helpers/anti_capture.lua` when deciding if a capture is allowed. No resolver stone-specific module.

## Stages helpers

Pure legality/board-query helpers used by stages (`stages_helpers/`). Example: anti-capture condition for legal moves. Not effects — no scoring, no state mutation beyond what the stage orchestrates.

## Placement record

`round_stone_effects` / placement context for the current play. Phased `apply` uses this when the stone is removed before the points phase (e.g. kamikaze).

## Defence network

When a defence stone is played (`on_play`), it adds solidity once to itself and connected friendly stones. The buff is permanent — nothing recalculates when stones are later captured or removed.

When any stone is played next to an already-placed defence stone, that new stone also gets the defence solidity buff. Cross-stone buffs like this are declared in `shared_stones_effects` so every stone picks them up without copy-paste.

## Shared stone effects

Reusable effect definitions applied to all stones (or a broad class) — e.g. pattern mult bonuses, defence-adjacency buffs. Declared once in `objects/definitions/shared_stones_effects.lua`; the resolver applies them during board scan or on-play as appropriate.

## Condition

Optional gate on an effect definition. Checked immediately before `apply`. If any condition fails, the effect is skipped. All object types (stone, card, stance) use the same condition list — no secret checks inside helpers.

## Tick step

At end of turn, one generic stage subtracts 1 from every timer field on the board (stones and other objects). It does not interpret what each timer means. Expired stones are removed in the remove-stones step; timer side effects (immunity fading, blockade shrinking) run via effects with `action = tick`.

## Removal effects dispatch

When a stone leaves the board, `on_removed` effects run only because the code that removed it says so — not because the board is secretly watched. Every removal path (capture, timer expiry, card, sacrifice) must call the removal-effects step explicitly.

**Sacrifice is not removal.** When a stone removes itself as part of play (e.g. kamikaze), `on_removed` effects do not run — only its `on_play` effects do.

## Navigation rule

Scoring: object def → factory → helper `apply`. Board rules: `resolver/stages/` + def-driven metadata.
