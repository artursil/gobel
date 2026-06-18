# ADR 0003: Pending stone removals and the removal beat

**Status:** accepted  
**Date:** 2026-06-18  
**Supersedes:** Placement pipeline step order and `remove_stones` responsibilities described in [ADR 0001](0001-stone-effects-stages-and-phases.md) (2026-06-14)  
**Related:** [ADR 0002](0002-effects-conditions-module.md), root `CONTEXT.md`, `mds/PRD_effects_conditions_module.md`

## Context

ADR 0001 placed **Remove stones** before phased `apply` on placement, with capture, kamikaze, timed expiry, and capture-stone logic implemented inside `remove_stones.lua` (driven from defs/tags). That kept board hygiene in one stage but:

- Stone-specific removal rules lived in stage code paths agents had to discover and extend.
- Removals happened before scoring animations, blocking a consistent **effects → animation → remove** beat.
- Capture stone duplicated concerns between Go capture rules and supplemental capture logic in the stage.

A grill session (2026-06-18) clarified that **effect rows own stone-specific removal intent**; stages drain a queue and run `dispatch_removed` — they do not decide *which* stones leave.

## Decision

### Pending stone removals queue

Match state carries **`state.pending_stone_removals`**: a list of entries `{ row, col, …metadata }`.

- **Effects enqueue** when a stone should leave the board (kamikaze after `on_play` score, lethal card damage at 0 solidity, self-destruct expire, capture-stone supplemental target, card destroy, …).
- **`remove_stones` stage drains** the queue after animations complete: clear cells, prisoners, **`dispatch_removed`** (so **`on_removed` effects run**).
- Stages must **not** contain `if stone_id ==` removal branches. Regular Go captures are the exception (see below).

Queue entries may include metadata (`capturer`, `reason`, `skip_on_removed` for sacrifice) so `dispatch_removed` behaves correctly.

### Removal beat (fixed sub-sequence)

Within on-play, on-card, and end-of-turn tick beats:

1. **Effect phases** (territory → points → mult, or `action = tick` passes) — may mutate board fields (solidity), enqueue removals, register animations.
2. **Animations** for the beat.
3. **Drain `pending_stone_removals`** — removal is always the **last step** of the animation sequence.

### On-play pipeline (replaces ADR 0001 steps 2–5 ordering)

After commit:

1. **Commit board** (regular Go captures applied here — immediate, no animation queue in this pass)
2. **Territory → Points → Mult** (`on_play` effects; enqueue removals)
3. **Animations**
4. **Remove stones stage** — drain queue, `dispatch_removed`
5. **Recalculate legal moves**

Kamikaze and similar: stone **scores while still on the board**, then enqueues self, then animates, then drains.

### End-of-turn tick pipeline

1. Generic decrement of `cell.duration_left` — no stone semantics
2. **`action = tick` effect phases** (expire hooks, payouts, enqueue removals)
3. **Animations**
4. **Drain `pending_stone_removals`**
5. Continue EOT work (`end_of_turn` effects, stances, …)

### Regular capture vs capture-stone supplemental

| Path | When | Owner |
|------|------|--------|
| **Regular Go capture** | At placement commit | `rules` — may remove many stones; **no** animation queue this pass |
| **Capture-stone supplemental** | After commit, in `on_play` points phase | Condition picks one extra enemy not already captured; returns `{ row, col }`; effect enqueues only that cell |

Regular capture has **priority** and must not be duplicated by the capture-stone effect.

### Lethal card damage

`damage_selected_stone` **apply** reduces solidity on the cell. At 0, **enqueue** on `pending_stone_removals` but **do not clear** the cell until post-animation drain (stone visible during animation).

### Timed stone expire rows

Separate **`effect_name` per beat** (strict def rows with `rounds`/`duration` from parameters):

| Stone | Setup (`on_play`) | Tick (`action = tick` at `duration_left == 0`) |
|-------|-------------------|--------------------------------------------------|
| delay_reward | `delay_reward_setup` | `delay_reward_payout` (pays; stone may stay) |
| self_destruct | `self_destruct_setup` | `self_destruct_expire` (**enqueues** removal) |
| anti_capture | `anti_capture_setup` | `anti_capture_expire` (**no-op** for now; no enqueue) |

### Sacrifice vs removal

**Sacrifice is not removal** (ADR 0001 unchanged): kamikaze queue entries carry metadata so **`on_removed` does not run**; only `on_play` effects ran earlier.

### Selected board targets (cards)

Card effects read **`state.resolution.selected_target(s)`** via shared helpers — not condition kwargs. Attack/Heal omit def-row conditions; Destroy/Forge keep gate conditions only.

## Consequences

### Positive

- New timed or removal stones add effect files + enqueue calls — not stage `if` branches.
- One animation → remove beat for effect-driven removals.
- Capture stone supplemental logic is testable via condition kwargs + enqueue.

### Implementation cost (historical)

- Reordered on-play pipeline (effects before remove stage).
- Introduced `pending_stone_removals` + shared enqueue helper.
- Refactored `remove_stones.lua` to drain queue; moved kamikaze, capture-stone supplemental, self-destruct expiry out of stage branches.
- Removed `tick_objects` → `on_tick` side door; per-stone tick semantics use `action = tick` + `effect_manager`.

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Keep remove-before-score (ADR 0001) | Blocks animation-last removal; kamikaze logic stays in stage |
| Stage interprets `duration_left == 0` for self-destruct | Stone logic in stage; user wants per-stone effect files |
| Capture stone fully in stage | No animation hook for supplemental capture; duplicates Go rules poorly |
| Pass selected target via condition kwargs | UI input already in resolution; conditions stay gate-only for cards |

## References

- Grill-with-docs session 2026-06-18
- `objects/effects_conditions/helpers/shared/pending_removals.lua`
- `single_game/resolver/stages/remove_stones.lua`
