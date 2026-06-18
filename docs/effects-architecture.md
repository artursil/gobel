# Stone effects architecture

Normative principles for stone behavior, resolver stages, and phased `apply`.  
**ADR:** [0001](adr/0001-stone-effects-stages-and-phases.md), [0002](adr/0002-effects-conditions-module.md), [0003](adr/0003-pending-stone-removals-and-removal-beat.md)  
**Glossary:** [CONTEXT.md](../CONTEXT.md) at repo root; module detail in [objects/effects_conditions/CONTEXT.md](../objects/effects_conditions/CONTEXT.md)

**Related:** `.cursor/rules/gobel-coding-standards.mdc`, `mds/OBJECTS.md`, `mds/GAME_RULES.md`, `mds/PRD_effects_conditions_module.md`

---

## 1. Core model

Stone **scoring, timers, and removal intent** live in **effects**. **Draining removals and legality refresh** live in resolver stages. Effects use **`apply(state, owner, kwargs)`** via the effects–conditions runner.

Effect definitions use **`action`** + **`phase`** (+ optional **`conditions`**). Canonical actions include `on_play`, `on_card`, `end_of_turn`, `tick`, `on_removed`.

```
stone definition
  └─ effects[]: { effect_name, action, phase, … }
       └─ objects/effects_conditions/effects.lua (registry)
            └─ effects/<effect_name>.lua
                 └─ build(effect) → { apply = function(state, owner, kwargs) … }
```

**Navigation — scoring:** definition → `effects/<effect_name>.lua` → runner → `conditions/<condition_name>.lua` → `apply`.  
**Navigation — removal drain / legality:** `resolver/stages/*.lua` (generic; no `if stone_id ==`).

The resolver **runs stages and phases in a fixed order**. The **only** resolver entry to effect `apply` is `objects.effects_conditions.run`.

---

## 2. Code layers

| Layer | Module | Responsibility | May mutate state? |
|-------|--------|----------------|-------------------|
| **Schema** | `EffectSchema`, `ConditionSchema`, `scheduling` | Validate defs at load time; enums; schedule parsing | No |
| **Registry** | `effects.lua`, `conditions.lua` | Route names → per-file modules | No |
| **Runner** | `run.lua` | Eval conditions → merge kwargs → `apply` | Orchestrates |
| **Effect files** | `effects/<name>.lua` | `build(effect)` → inline `apply` | Yes (via apply) |
| **Condition files** | `conditions/<name>.lua` | `eval(state, owner, condition_def) → pass, fragment` | No (fragments only) |
| **Shared helpers** | `helpers/shared/*` | Reusable math, enqueue removals, placement reads | Usually yes when called from apply |
| **Resolver stages** | `resolver/stages/*.lua` | Drain removal queue, legality, generic timer decrement | Yes (orchestrated) |

**Rule of thumb**

- Score, timers on cells, blockade maps, energy, **enqueue removals** → effect `apply` + `helpers/shared`
- **Drain** `pending_stone_removals`, `dispatch_removed`, prisoners → **`remove_stones` stage**
- Regular Go capture at placement → **`rules` at commit** (immediate; no animation queue this pass)
- Playability / immunity / blockade → **`legality_of_moves` stage** + `rules`
- Generic countdown decrement → **generic tick stage** (no stone semantics)

Do not put business logic in registry files or stone-specific branches in resolver stages.

---

## 3. Kwargs contract

1. Conditions on an effect each return `(pass, fragment)`. All must pass.
2. Fragments merge into one `kwargs` table (duplicate keys across conditions on the same effect are invalid at schema load).
3. `apply` always receives `(state, owner, kwargs)`.
4. **Computed** values come from conditions (wall `{ blocks }`, capture-stone supplemental `{ row, col }`).
5. **UI / resolution input** (selected board target, placement coords) is read inside shared helpers from `state` — not copied into kwargs for card targeting.
6. Def fields (`value`, `rounds`, `duration`, …) are closed over in `build` — not kwargs.
7. Required kwargs keys must error when absent (`helpers/shared/require_kwargs.lua`).

### Stone-context kwargs (registry convention)

Board-scanned stone effects receive placement context from the registry, not extra `apply` parameters. `effects.wrap_board_scan` merges `{ row, col, cell, stone_def }` into kwargs before calling the effect's `apply`. Removal dispatch passes `{ row, col, cell, opts }` the same way. The registry routes only; it does not interpret stone semantics.

---

## 4. Removal beat

Effect-driven removals follow a fixed sub-sequence:

1. **Effect phases** — mutate fields, enqueue `pending_stone_removals`, request animations
2. **Animations**
3. **Drain queue** — `remove_stones` clears cells, runs `dispatch_removed` (**`on_removed` fires** except sacrifice metadata)

### On-play pipeline

| Step | What happens |
|------|----------------|
| 1 | **Commit board** — regular Go captures at commit |
| 2 | **Territory → Points → Mult** — `on_play` effects |
| 3 | **Animations** |
| 4 | **Remove stones** — drain `pending_stone_removals` |
| 5 | **Recalculate legal moves** |

### End-of-turn tick

| Step | What happens |
|------|----------------|
| 1 | Decrement `duration_left` (generic) |
| 2 | **`action = tick` effect phases** |
| 3 | **Animations** |
| 4 | **Drain `pending_stone_removals`** |
| 5 | **`end_of_turn` and other EOT work** |

### Placement record

On-play effects for the current placement run from **`round_stone_effects` / placement context** even when the stone is queued for removal in the same beat (kamikaze).

---

## 5. Captures

| Kind | Owner | Animation |
|------|--------|-----------|
| **Regular Go capture** | `rules` at commit | None this pass |
| **Capture-stone supplemental** | Condition picks `{ row, col }` not already captured; effect enqueues one cell | Yes (removal beat) |

---

## 6. Stages (not effects)

### Remove stones (`resolver/stages/remove_stones.lua`)

Drains **`state.pending_stone_removals`**: clear cells, prisoners, **`dispatch_removed`**. Does **not** decide which stones leave — effects enqueue first.

Sacrifice queue entries carry metadata so **`on_removed` is skipped** (kamikaze).

### Legality of moves (`resolver/stages/legality_of_moves.lua`)

Rebuilds cached legal placements from board, ko ban, blockade, and anti-capture immunity (`cell.duration_left` > 0).

### Tick decrement (generic)

Subtracts 1 from `cell.duration_left` without interpreting stone meaning. Expire semantics live in **`action = tick` effect rows**.

---

## 7. Effects and phases

### Single hook: `apply(state, owner, kwargs)`

Every resolved effect exposes **`apply` only** — scheduled via `action` + `phase`, built inline in `effects/<name>.lua`.

| Stone / behavior | `action` | `phase` | Notes |
|------------------|----------|---------|--------|
| add_points | `on_play` | `points` | Placement record |
| wall_stone | `on_play` | `points` | Condition `{ blocks }` |
| kamikaze_sacrifice | `on_play` | `points` | Scores, enqueues self (sacrifice) |
| delay_reward_setup / payout | `on_play` / `tick` | `points` | Setup sets `duration_left`; payout at 0 |
| self_destruct_setup / expire | `on_play` / `tick` | `points` | Expire enqueues removal |
| anti_capture_setup / expire | `on_play` / `tick` | — | Expire no-op for now |
| capture_zero_liberty_enemy | `on_play` | `points` | Condition `{ row, col }`; enqueue supplemental |
| damage_selected_stone | `on_card` | `points` | Solidarity ↓; enqueue at 0 |
| tax_enclosure_enemies | `end_of_turn` | `points` | Enclosure scan |
| escalating capture penalty | `on_removed` | `points` | Via `dispatch_removed` |

Timed stones use **separate `effect_name`s per beat**; strict `rounds`/`duration` on setup defs.

Scheduling enums and parsing live in `objects/effects_conditions/scheduling.lua` (re-exported from `EffectSchema`).

---

## 8. State modeling

Definitions (`objects/definitions/*`) are immutable. Runtime state lives on board cells, players, match score bags, and **`pending_stone_removals`**. Stone countdown: **`cell.duration_left`**.

---

## 9. Resolver responsibilities

- Run placement pipeline: commit → phased apply → animate → drain removals → legality
- Run other beats (`on_card`, `end_of_turn`, `tick`, `on_removed`, `board_reconcile`) via `effect_manager` + `run.lua`
- AI placement scoring mirrors the same action / phase / placement record

The resolver must **not** call effect helpers directly or contain stone-specific gameplay branches.

---

## 10. Tests

- **Unit:** schema, `build`/`apply`, condition `eval`, `pending_stone_removals` enqueue/drain, stages with seeded boards
- **Integration:** full placement + EOT pipelines per stone cluster; removal beat ordering
- **Visual:** frozen scenarios; update only when behavior genuinely changed

Run the full busted suite when touching stages, phases, or effects.

---

## 11. Reviewer checklist

- [ ] Stone def has `effect_name`, `action`, `phase` (schema rejects `macro`, `sub`, `when`, `lifecycle`)
- [ ] Logic in `effects/<name>.lua` + `helpers/shared/`; registry routes only
- [ ] `apply(state, owner, kwargs)` only; board-scanned stones get context via `wrap_board_scan`
- [ ] Removals enqueue — stage does not branch on stone id
- [ ] Conditions return fragments for computed values; cards read resolution for targets
- [ ] Timed setup defs declare `rounds`/`duration` from parameters
- [ ] No top-level `objects/effects` or `helpers/effects/` in new code

---

## 12. Anti-patterns

| Anti-pattern | Why it fails |
|--------------|--------------|
| `macro`, `sub`, `when`, or `lifecycle` on effect defs | Schema rejects at load; use `action` + `phase` |
| `on_tick` on resolved effects | Bypasses `action = tick` scheduling |
| `EffectSchema.build` / `kwargs_from_def` | Hidden def→kwargs injection |
| Extra `apply` parameters beyond kwargs | Breaks runner contract |
| Clearing board in `apply` without enqueue | Skips animation-last removal beat |
| Stone-specific logic in `remove_stones` | Violates ADR 0003 |
| Duplicating regular Go capture in capture-stone effect | Regular capture has priority |
| Business logic in registry files | Hard to review and test |
| `helpers/effects/` per-effect trees | Superseded by `effects/<name>.lua` + `helpers/shared/` |
