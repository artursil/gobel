# ADR 0001: Stone effects via resolver stages and phased apply

**Status:** accepted  
**Date:** 2026-06-14  
**Supersedes:** Hook-based placement model (Phase 1 `placement_runner`, `on_compile` / `on_placement`, `lifecycle` on defs) described in earlier drafts of this branch.

## Context

Stone behavior was split across:

- Placement hooks (`on_compile`, `on_finalize_compile`, `on_snapshot`, `on_placement`)
- A parallel `lifecycle` field and `macro` / `sub` scoring axes
- Stone-specific branches in `resolver.lua` and orphan resolver modules (`copper_stone.lua`, `retrigger_stone.lua`, …)

That made it hard to answer “what happens when I play a stone?” without reading several pipelines. A grill session clarified the intended model:

- **Board hygiene** (capture, sacrifice removal, expiry) is generic resolver work, not per-stone hooks.
- **Legality** (anti-capture immunity, blockade) updates a cached legal-move set, not placement-time effect hooks.
- **Scoring and cell setup** use a single `apply` on effects, scheduled by an ordered **phase** list.
- Territory multiplier / control stones should use existing **`territory_control_rounds`** state rather than ad-hoc placement snapshots.

## Decision

Adopt a **stage + phase** pipeline.

### Placement resolve order (fixed)

After a stone is committed to the board:

1. **Commit placement** — write `state.board`
2. **Remove stones** (`resolver/stages/remove_stones.lua`) — inspect board; resolve captures and removals (including kamikaze self-removal, timed expiry); award capture points where rules say so
3. **Territory phase** — run `apply` for effects with `phase = "territory"`
4. **Points phase** — run `apply` for effects with `phase = "points"`
5. **Mult phase** — run `apply` for effects with `phase = "mult"`
6. **Recalculate legal moves** (`resolver/stages/legality_of_moves.lua`) — refresh cached legality from board + immunity + blockade + ko

Other match beats (end of turn, tick, on removed, board reconcile) invoke the same **phase ordering** where applicable, gated by **`action`** on the effect definition (see `docs/effects-architecture.md`).

### Effects

- Each stone effect declares `effect_name`, **`action`**, and `phase`.
- Resolved effects expose **`apply` only** — no `on_compile`, `on_placement`, or other placement hooks.
- Factories delegate to helper modules under `objects/effects_conditions/effects/` (see [ADR 0002](0002-effects-conditions-module.md)).

### Stages vs effects

| Concern | Owner |
|---------|--------|
| Capture, sacrifice removal, timed stone removal | `remove_stones` stage (rules driven from defs/tags, not `if stone_id ==`) |
| Whether a intersection is playable | `legality_of_moves` stage + `rules` |
| Points, mult, territory scoring, timers on commit, blockade registration | Effect `apply` in the matching phase |
| Immunity decay, blockade tick | `action = tick` effect rows + generic `duration_left` decrement |
| Defence solidity recompute | `board_reconcile` beat after topology changes |

### Placement scoring when the stone is already removed

Some stones (e.g. kamikaze) leave the board in step 2 but must score in step 4. **Points/mult `apply` for the current placement uses the placement record** (`round_stone_effects` / placement context), not “find this kind on the board.”

### Dropped concepts

- **`lifecycle`** on stone defs — replaced by `action` + `phase` + stage schedule
- **Placement hooks** — replaced by stages + phased `apply`
- **`macro` / `sub` / `when` on stone defs** — replaced by `action` + `phase`; schema rejects legacy fields at load

## Consequences

### Positive

- One mental model: commit → remove → territory → points → mult → legality
- Capture and kamikaze removal live in one stage file, not scattered hooks
- Anti-capture is legality, matching how players experience “I can’t capture that group”
- Effects stay thin: one `apply`, one helper module per `effect_name`

### Implementation cost (historical)

- Phase 1 hook infrastructure on `agent/merge-issues-28-38` was **reverted or replaced**
- `docs/effects-architecture.md` and `CONTEXT.md` rewritten; PRD checklist updated
- Schema validation requires `action` + `phase` (rejects `lifecycle`, `macro`, `sub`)
- Visual specs remain frozen; implementation must match scenarios under the new pipeline

### Follow-up implementation order

1. Revert hook-based placement runner and hook fields on factories
2. Add `resolver/stages/remove_stones.lua` and `legality_of_moves.lua`
3. Refactor resolve pipeline to run stages + phased `apply`
4. Migrate stone helpers (`apply`-only) in small batches
5. Delete obsolete resolver stone modules

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Placement hooks (`on_compile`, `on_placement`, …) | Duplicates a hidden schedule; same work as phases but harder to navigate |
| Keep `lifecycle` + `macro`/`sub` | Three overlapping “when” systems; user-facing confusion |
| Capture/kamikaze as special effects | Hides board rules in effect hooks instead of `remove_stones` stage |
| `territory_to_multiplier_snapshot` hook | Redundant with `territory_control_rounds` and phased mult `apply` |
