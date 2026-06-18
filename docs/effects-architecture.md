# Stone effects architecture

Normative principles for stone behavior, resolver stages, and phased `apply`.  
**ADR:** [0001-stone-effects-stages-and-phases.md](adr/0001-stone-effects-stages-and-phases.md), [0002-effects-conditions-module.md](adr/0002-effects-conditions-module.md)  
**Glossary:** [CONTEXT.md](../CONTEXT.md) at repo root; module detail in [objects/effects_conditions/CONTEXT.md](../objects/effects_conditions/CONTEXT.md)

**Related:** `.cursor/rules/gobel-coding-standards.mdc`, `mds/OBJECTS.md`, `mds/GAME_RULES.md`

---

## 1. Core model

Stone **scoring and cell setup** live in effects. **Board hygiene and legality** live in resolver stages. Effects use **`apply(state, owner, kwargs)`** via the effects–conditions runner.

Effect definitions use **`action`** + **`phase`** (+ optional **`conditions`**). Canonical actions include `on_play`, `on_card`, `end_of_turn`, `tick`, `on_removed`.

```
stone definition
  └─ effects[]: { effect_name, action, phase, … }
       └─ objects/effects_conditions/effects.lua (dispatch)
            └─ helpers/effects/<name>.lua
                 └─ apply(state, owner, kwargs)
```

**Navigation — scoring:** definition → `effect_name` → dispatch → helper `apply`.  
**Navigation — capture / removal / legality:** `resolver/stages/*.lua` (generic; stone rules via defs/tags, not `if stone_id ==`).

The resolver **runs stages and phases in a fixed order**. It does **not** embed stone-specific gameplay branches. The **only** resolver entry to effect apply is `objects.effects_conditions.run`.

---

## 2. Code layers

| Layer | Module | Responsibility | May mutate state? |
|-------|--------|----------------|-------------------|
| **Schema** | `EffectSchema`, `ConditionSchema`, `scheduling` | Validate rows; enums; schedule parsing | No |
| **Dispatch** | `effects.lua`, `conditions.lua` | Map names → helpers; thin wiring only | No |
| **Runner** | `run.lua` | Eval conditions → merge kwargs → `apply` | Orchestrates |
| **Effect helpers** | `helpers/effects/*` | One `effect_name`; `apply(state, owner, kwargs)` | Yes |
| **Condition helpers** | `helpers/conditions/*` | `eval(state, owner) → pass, fragment` | No (fragments only) |
| **Shared helpers** | `helpers/shared/*` | Pure or cross-cutting utilities | Usually no |
| **Resolver stages** | `resolver/stages/*.lua` | Generic board/legality pipeline | Yes (orchestrated) |

**Rule of thumb**

- Score, timers on cells, blockade maps, energy → **effect helper** `apply`
- Capture, sacrifice removal, expiry removal → **`remove_stones` stage**
- Playability / immunity / blockade for legality → **`legality_of_moves` stage** + `rules`
- Reusable math with no side effects → **`helpers/shared`**

Do not put business logic in dispatch files, the resolver, or top-level `objects` shims (removed in Phase 5).

---

## 3. Kwargs contract

1. Conditions on an effect each return `(pass, fragment)`. All must pass.
2. Fragments merge into one `kwargs` table (duplicate keys across conditions on the same effect are invalid at schema load).
3. `apply` always receives `(state, owner, kwargs)`.
4. Placement row/col, removal cell, and tick context are read **inside** helpers from `state` / resolution metadata unless explicitly passed in `kwargs` from conditions.
5. Required kwargs keys must error when absent (`helpers/shared/require_kwargs.lua`).

---

## 4. Placement pipeline (fixed order)

When a stone is played and committed:

| Step | Name | What happens |
|------|------|----------------|
| 1 | **Commit placement** | Write `state.board` |
| 2 | **Remove stones** | Stage: captures, zero-liberty removal (when rules/def say so), kamikaze self-removal, timed expiry; capture points |
| 3 | **Territory phase** | Run `apply` for effects with `phase = "territory"` |
| 4 | **Points phase** | Run `apply` for effects with `phase = "points"` |
| 5 | **Mult phase** | Run `apply` for effects with `phase = "mult"` |
| 6 | **Recalculate legal moves** | Stage: refresh cached legality (immunity, blockade, ko, …) |

### Placement record

Effects for the **current placement** run from the **placement record** (`round_stone_effects` / placement context), not only from scanning the board. Required when step 2 removes the placed stone before step 4 (kamikaze).

### Other match beats

The same **phase order** (territory → points → mult) applies within each beat. Effects declare **`action`** (legacy docs may say `when`):

| `action` | Invoked |
|----------|---------|
| `on_play` | After a stone placement (pipeline below) |
| `on_card` | After a card is played |
| `end_of_turn` | End-of-turn resolve for active player |
| `tick` | Between turns / round boundary (timers, blockade decay, immunity decay) |
| `on_removed` | When a stone leaves the board (cross-player penalties, bank transfer) |
| `board_reconcile` | After any board topology change (defence solidity network) |

Scheduling enums and parsing live in `objects/effects_conditions/scheduling.lua` (re-exported from `EffectSchema`).

---

## 5. Stages (not effects)

### Remove stones (`resolver/stages/remove_stones.lua`)

Inspects the board after commit and removes stones that should not remain:

- Normal Go capture resolution
- Special capture rules declared on defs (e.g. zero-liberty enemy removal for capture stone) — invoked **generically** from def metadata/tags, not hardcoded `kind` checks
- Sacrifice / self-removal (kamikaze)
- Timed self-destruct expiry (when timer reaches zero)

Awards capture / prisoner points according to game rules. **Not** an effect hook per stone.

### Legality of moves (`resolver/stages/legality_of_moves.lua`)

Rebuilds cached legal placements from board, ko ban, blockade zones, and anti-capture immunity (`cell.immunity_remaining`).

---

## 6. Effects and phases

### Single hook: `apply(state, owner, kwargs)`

Every effect helper implements `apply` with the kwargs contract above. Resolved effects may also expose `on_tick` for round-boundary decay (blockade, immunity cleanup, delayed payout).

- **`phase`** selects the pass: `territory` | `points` | `mult`
- **`action`** selects the beat (see table above)

Examples:

| Stone / behavior | `action` | `phase` | Notes |
|------------------|----------|---------|--------|
| add_points | `on_play` | `points` | Uses placement record |
| wall_stone | `on_play` | `points` | Group size at placement |
| mult_control_streak | `on_play` | `mult` | Reads `territory_control_rounds` |
| delay_reward_survival | `on_play` | `points` | Starts `survival_rounds_remaining`; `on_tick` pays out |
| blockade_adjacent | `on_play` | `points` | Writes board-zone blockade map; `on_tick` decays |
| tax_enclosure_enemies | `end_of_turn` | `points` | Enclosure scan |
| escalating capture penalty | `on_removed` | `points` | Cross-player |

---

## 7. State modeling

Definitions (`objects/definitions/*`) are immutable. Runtime state lives on board cells, players, and match score bags. See ADR 0001 for cell fields (`immunity_remaining`, `stored_value`, blockade maps, etc.).

---

## 8. Resolver responsibilities

- Run placement pipeline: commit → remove_stones → territory → points → mult → legality
- Run other beats (`end_of_turn`, `tick`, `on_removed`, `board_reconcile`) with phased apply via `effect_manager` + `run.lua`
- AI placement scoring mirrors the same action / phase / placement record as the resolver

The resolver must **not** call effect helpers directly or contain stone-specific gameplay branches.

---

## 9. Tests

- **Unit:** schema, helper `apply`, condition `eval`, stage modules with seeded boards
- **Integration:** full placement pipeline per stone cluster
- **Visual:** frozen scenarios; assert-value fixes only when behavior genuinely changed

Run the full busted suite when touching stages, phases, or effects.

---

## 10. Reviewer checklist

- [ ] Stone def has `effect_name`, `action`, `phase`
- [ ] Dispatch delegates to `helpers/effects/<name>.lua`; `apply(state, owner, kwargs)` only
- [ ] Conditions return fragments; runner merges kwargs
- [ ] Capture/removal not implemented as effect hooks
- [ ] Immunity affects legality stage, not placement hook
- [ ] No top-level `objects/effects` or `helper_effects` paths in new code
- [ ] Docstrings on dispatch, helpers, and stages

---

## 11. Anti-patterns

| Anti-pattern | Why it fails |
|--------------|--------------|
| Requiring deleted shims (`objects/effects`, `effect_enums`, resolver `Effect`) | Use `objects.effects_conditions.*` |
| Calling helpers from resolver | Use `run.lua` only |
| Extra `apply` parameters beyond kwargs | Breaks runner contract |
| Business logic in dispatch files | Hard to review and test |
| `helper_effects/` or monolithic registry | Removed; one helper per effect under `helpers/effects/` |
