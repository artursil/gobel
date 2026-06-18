# Gobel — domain glossary

Canonical terms for stone effects architecture. Normative detail: `docs/effects-architecture.md`, [ADR 0001](docs/adr/0001-stone-effects-stages-and-phases.md), [ADR 0003](docs/adr/0003-pending-stone-removals-and-removal-beat.md).

## Effect

Object behavior on a definition: `effect_name` + **`action`** + `phase`, optional `conditions`. One object can have **many effect rows** (e.g. `on_play`, `tick`, `end_of_turn`, `on_removed`). Each resolves to **`apply` only** — no other hooks on the resolved table. Implementation: `objects/effects_conditions/effects/<effect_name>.lua`.

## Action

Which match beat invokes the effect. Canonical values (enum): `game_start`, `before_turn`, `on_card`, `on_play`, `end_of_turn`, `tick`, `on_removed`, `game_end`.

## Phase

Which scoring pass runs the effect: `territory`, `points`, or `mult`. Order within a beat is always territory → points → mult.

## Resolver stage

Generic pipeline module under `single_game/resolver/stages/`. Updates board or legality without object-specific `if kind ==` branches.

## On-play pipeline

After a stone is committed:

1. **Commit board**
2. **Territory phase** → **Points phase** → **Mult phase** (effects run; may enqueue on `pending_stone_removals` or request animations)
3. **Animations** (attack bounce, self-destruct flash, …)
4. **Remove stones stage** — drain `pending_stone_removals` **after animation finishes**; clear cells, `dispatch_removed`, prisoners
5. **Recalculate legal moves**

Score/effects first, then animate, then remove as the final animation beat. Kamikaze: points while stone still on board; removal after its animation.

**Lethal damage (e.g. Attack I):** `apply` reduces cell solidity; at 0, enqueue on `pending_stone_removals` but leave the stone visible until animation completes and the remove stage drains the queue.

## Regular capture

Standard Go captures from `rules` (zero-liberty groups after placement). Can remove **many** stones at once. Runs **first** at placement commit — **outside** `pending_stone_removals` and outside capture-stone effect `apply`. Has priority over capture-stone supplemental rules. **No animation queue in this pass** — immediate at commit; effect-driven removals get animate → drain later.

## Capture stone supplemental capture

Extra removal from the **capture stone** special rule (one enemy at zero empty neighbors, RNG pick). Only stones **not already removed by regular capture** are eligible. A **condition** consults general capture state, picks the supplemental target, and returns **`pass, { row, col }`**. **`capture_zero_liberty_enemy` `apply`** enqueues that cell on `pending_stone_removals` → animation → drain. Does not re-run or duplicate regular captures.

## Pending stone removals

Queue on match state (e.g. `state.pending_stone_removals`) populated by **effect `apply`** when a stone should leave the board (self-destruct expire, kamikaze, card destroy, capture-stone supplemental target, …). The **remove-stones stage** only drains this queue — no `if stone_id ==` or per-stone branches in stages.

Each entry names **row/col** (and optional metadata: reason, capturer). Stages clear cells, run `dispatch_removed`, and prisoners **after animation completes** — removal is always the **last beat** of the animation sequence, not before it.

**Anti-capture expire** does not enqueue — immunity ends; stone stays.

## Remove stones stage

Generic pipeline step that **drains `pending_stone_removals`**, clears board cells, and runs **`dispatch_removed`** (so **`on_removed` effects still fire** for queued removals). Does not encode stone-specific rules; effects enqueue first.

## Legality of moves

Final on-play step. Refreshes cached legal placements from board, immunity, blockade, ko. Immunity and similar checks use helpers from `stages_helpers/` (e.g. anti-capture condition) — not effect hooks.

## Anti-capture immunity

`on_play` effect sets `duration_left` on the cell (from parameters via def). Generic tick stage decrements it. Legality reads the field via `stages_helpers/anti_capture.lua`.

## Stages helpers

Pure legality/board-query helpers used by stages (`stages_helpers/`). Example: anti-capture condition for legal moves. Not effects — no scoring, no state mutation beyond what the stage orchestrates.

## Placement record

`round_stone_effects` / placement context for the current play. Phased `apply` uses this so on-play effects still run in the same beat even when the stone is queued for removal afterward (e.g. kamikaze).

## Duration left

Unified countdown: **`cell.duration_left`** on placed stones; **`instance.duration.remaining_rounds`** on ObjectInstances. Generic stage decrements. Timed stones use separate effect rows with **`action = tick`** (and `on_play` setup); each row has **`apply` only**.

**Strict defs:** the `on_play` row that sets `duration_left` must include `rounds` or `duration` from parameters on the definition — schema rejects the row if absent (no builder fallback).

**Timed effect names:** separate `effect_name` per beat (e.g. `delay_reward_setup` + `delay_reward_payout`) — one file per name; not one file branching on `action`.

**Self-destruct:** `self_destruct_setup` (`on_play`) + `self_destruct_expire` (`tick` at `duration_left == 0`). Expire enqueues removal on `pending_stone_removals` (no-op enqueue OK until animation exists); remove-stones stage drains the queue.

**Anti-capture:** `anti_capture_setup` (`on_play`) + `anti_capture_expire` (`tick` at `duration_left == 0`). Expire no-op for now; does **not** enqueue — stone stays; legality reads `duration_left`.

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

**Attack I / Heal I:** no conditions on the effect row — resolver `validate_card_targets` is authoritative. **Destroy / Forge Mark:** keep optional gate conditions (`selected_target_exists`, enemy/friendly) as a second check at apply time.

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

At end of turn: (1) generic decrement of timer fields (`duration_left`, …); (2) **`action = tick` effect phases** (enqueue removals, expire hooks); (3) **animations**; (4) **drain `pending_stone_removals`** after animation completes.

## Removal effects dispatch

When a stone leaves the board, `on_removed` effects run only because the code that removed it says so — not because the board is secretly watched. Draining **`pending_stone_removals`** must call **`dispatch_removed`** like any other removal path.

**Sacrifice is not removal.** When a stone removes itself as part of play (e.g. kamikaze), `on_removed` effects do not run — only its `on_play` effects do. Queue entries for sacrifice must carry metadata so `dispatch_removed` skips `on_removed`.

## Navigation rule

Scoring: object def → `effects/<effect_name>.lua` → runner → `conditions/<condition_name>.lua`. Shared math: `helpers/shared/`. Board rules: `resolver/stages/`.

## Migration order (effects–conditions module)

0. **`pending_stone_removals` + pipeline reorder** — ADR 0003; enqueue/drain, effects-before-remove, animation-last.
1. **Wall stone** — template slice (`wall_stone` + `wall_part_of_wall`; file split, inline `apply`, drop `EffectSchema.build`).
2. **Selected-stone cards** — attack/heal/destroy/forge; state-read targeting; Attack/Heal without def-row conditions.
3. **Timed stones** — `cell.duration_left`, separate effect names per beat, `action = tick`, remove `on_tick` path.
4. **Remainder** — capture stone supplemental condition, kamikaze enqueue, shrink monolithic `effects.lua` to registry-only.
