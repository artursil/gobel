# ADR 0001: Stone effects via resolver stages and phased apply

**Status:** accepted (placement pipeline **amended** — see [ADR 0003](0003-pending-stone-removals-and-removal-beat.md))  
**Date:** 2026-06-14  
**Supersedes:** Hook-based placement model (Phase 1 `placement_runner`, `on_compile` / `on_placement`, `lifecycle` on defs) described in earlier drafts of this branch.

## Context

Stone behavior was split across:

- Placement hooks (`on_compile`, `on_finalize_compile`, `on_snapshot`, `on_placement`)
- A parallel `lifecycle` field and `macro` / `sub` scoring axes
- Stone-specific branches in `resolver.lua` and orphan resolver modules (`copper_stone.lua`, `retrigger_stone.lua`, …)

That made it hard to answer “what happens when I play a stone?” without reading several pipelines. A grill session clarified the intended model:

- **Board hygiene** (draining effect-enqueued removals, regular Go capture at commit) is generic resolver work, not per-stone hooks in stages.
- **Legality** (anti-capture immunity, blockade) updates a cached legal-move set, not placement-time effect hooks.
- **Scoring and cell setup** use a single `apply` on effects, scheduled by an ordered **phase** list.
- Territory multiplier / control stones should use existing **`territory_control_rounds`** state rather than ad-hoc placement snapshots.

## Decision

Adopt a **stage + phase** pipeline.

### Placement resolve order (fixed)

> **Amended by ADR 0003 (2026-06-18).** Authoritative order:

After a stone is committed to the board:

1. **Commit placement** — write `state.board` (regular Go captures at commit)
2. **Territory phase** → **Points phase** → **Mult phase** — run `apply` for `on_play` effects; effects may enqueue `pending_stone_removals`
3. **Animations**
4. **Remove stones** — drain `pending_stone_removals`, `dispatch_removed`, prisoners
5. **Recalculate legal moves** — refresh cached legality from board + immunity + blockade + ko

See [ADR 0003](0003-pending-stone-removals-and-removal-beat.md) for capture-stone split, card damage, and EOT tick ordering.

Other match beats (end of turn, tick, on removed, board reconcile) invoke the same **phase ordering** where applicable, gated by `when` on the effect definition (see `docs/effects-architecture.md`).

### Effects

- Each stone effect declares `effect_name`, `when`, and `phase`.
- Resolved effects expose **`apply` only** — no `on_compile`, `on_placement`, or other placement hooks.
- Factories delegate to per-name files under `objects/effects_conditions/effects/` (see [ADR 0002](0002-effects-conditions-module.md)).

### Stages vs effects

| Concern | Owner |
|---------|--------|
| Regular Go capture at commit | `rules` at board commit (immediate; no animation queue this pass) |
| Effect-driven removals (kamikaze, self-destruct expire, supplemental capture stone, lethal cards, …) | Effect `apply` enqueues → animations → `remove_stones` drains queue |
| Whether a intersection is playable | `legality_of_moves` stage + `rules` |
| Points, mult, territory scoring, timers on commit, blockade registration | Effect `apply` in the matching phase |
| Timer decrement | Generic tick stage (dumb infrastructure) |
| Timer expire hooks / payouts | `action = tick` effect rows via `effect_manager` + runner |
| Defence solidity recompute | `board_reconcile` beat after topology changes |

### Placement scoring when the stone is already removed

Some stones (e.g. kamikaze) enqueue removal after scoring in the same beat. **Points/mult `apply` for the current placement uses the placement record** (`round_stone_effects` / placement context), not “find this kind on the board.”

### Dropped concepts

- **`lifecycle`** on stone defs — replaced by `when` + `phase` + stage schedule
- **Placement hooks** — replaced by stages + phased `apply`
- **`macro` / `sub` on stone defs** — replaced by `when` + `phase` (legacy fields may remain temporarily during migration)

## Consequences

### Positive

- One mental model: commit → score phases → animate → drain removals → legality
- Effect-driven removals live in per-stone effect files; stage only drains queue
- Anti-capture is legality, matching how players experience “I can’t capture that group”
- Effects stay thin: one `apply` per effect row, one file per `effect_name`

### Negative / migration cost

- Phase 1 hook infrastructure on `agent/merge-issues-28-38` must be **reverted or replaced**, not extended
- `docs/effects-architecture.md` and `CONTEXT.md` rewritten; PRD checklist updated
- Schema validation changes (`when`, `phase` instead of `lifecycle`, `macro`, `sub`)
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
| Capture/kamikaze as special effects | Hides removal intent; use enqueue + ADR 0003 pipeline instead |
| `territory_to_multiplier_snapshot` hook | Redundant with `territory_control_rounds` and phased mult `apply` |
