# Stone effects architecture

Normative principles for stone behavior, resolver stages, and phased `apply`.  
**ADR:** [0001-stone-effects-stages-and-phases.md](adr/0001-stone-effects-stages-and-phases.md)  
**Glossary:** [CONTEXT.md](../CONTEXT.md) at repo root  

**Related:** `.cursor/rules/gobel-coding-standards.mdc`, `mds/OBJECTS.md`, `mds/GAME_RULES.md`

---

## 1. Core model

Stone **scoring and cell setup** live in effects. **Board hygiene and legality** live in resolver stages. Effects use **`apply` only**.

Effect definitions use **`action`** + **`phase`** (+ optional **`conditions`**). Canonical actions include `on_play`, `on_card`, `end_of_turn`, `tick`, `on_removed`.

```
stone definition
  └─ effects[]: { effect_name, when, phase, … }
       └─ effect factory (registry)
            └─ helper effect module
                 └─ apply(state, …)
```

**Navigation — scoring:** definition → `effect_name` → factory → helper `apply`.  
**Navigation — capture / removal / legality:** `resolver/stages/*.lua` (generic; stone rules via defs/tags, not `if stone_id ==`).

The resolver **runs stages and phases in a fixed order**. It does **not** embed stone-specific gameplay branches.

---

## 2. Code layers

| Layer | Responsibility | May mutate state? |
|-------|----------------|-------------------|
| **Effect factories** | Map `effect_name` → resolved effect with `apply`; thin wiring only | No (delegate) |
| **Helper effects** | One `effect_name` (or family); implements `apply` | Yes |
| **Effect helpers** | Pure utilities: coords, group sizing, tag checks | No |
| **Resolver stages** | Generic board/legality pipeline (`remove_stones`, `legality_of_moves`, …) | Yes (orchestrated) |

**Rule of thumb**

- Score, timers on cells, blockade maps, energy → **helper effect** `apply`
- Capture, sacrifice removal, expiry removal → **`remove_stones` stage**
- Playability / immunity / blockade for legality → **`legality_of_moves` stage** + `rules`
- Reusable math with no side effects → **effect helpers**

Do not put non-factory functions in the effect registry module.

---

## 3. Placement pipeline (fixed order)

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

The same **phase order** (territory → points → mult) applies within each beat. Effects declare **`when`**:

| `when` | Invoked |
|--------|---------|
| `on_play` | After a stone placement (pipeline below) |
| `on_card` | After a card is played |
| `end_of_turn` | End-of-turn resolve for active player |
| `tick` | Between turns / round boundary (timers, blockade decay, immunity decay) |
| `on_removed` | When a stone leaves the board (cross-player penalties, bank transfer) |
| `board_reconcile` | After any board topology change (defence solidity network) |

There is **no** separate `lifecycle`, legacy `macro`/`sub`, or `board_reconcile` action on stone defs — only `action` + `phase`.

---

## 4. Stages (not effects)

### Remove stones (`resolver/stages/remove_stones.lua`)

Inspects the board after commit and removes stones that should not remain:

- Normal Go capture resolution
- Special capture rules declared on defs (e.g. zero-liberty enemy removal for capture stone) — invoked **generically** from def metadata/tags, not hardcoded `kind` checks
- Sacrifice / self-removal (kamikaze)
- Timed self-destruct expiry (when timer reaches zero)

Awards capture / prisoner points according to game rules. **Not** an effect hook per stone.

### Legality of moves (`resolver/stages/legality_of_moves.lua`)

Rebuilds cached legal placements (e.g. `state.legal_moves` or equivalent) from:

- Current board
- Ko ban
- Blockade zones
- Anti-capture immunity (`cell.immunity_remaining`) — **legality**, not a placement hook

`rules.lua` keeps suicide overrides (e.g. kamikaze). Validation reads the cache; UI mirrors resolver.

---

## 5. Effects and phases

### Single hook: `apply`

Every effect implements:

```lua
apply(state, owner, row, col, ctx)
```

- **`phase`** selects the pass: `territory` | `points` | `mult`
- **`when`** selects the beat (see table above)
- **`ctx`** carries placement context when the stone may no longer be on the board

Examples:

| Stone / behavior | `when` | `phase` | Notes |
|------------------|--------|---------|--------|
| add_points | `playing_stones` | `points` | Uses placement record |
| wall_stone | `playing_stones` | `points` | Group size at placement |
| mult_control_streak | `playing_stones` | `mult` | Reads `territory_control_rounds` |
| delay_reward_survival | `playing_stones` | `points` | Starts `survival_rounds_remaining` on cell |
| blockade_adjacent | `playing_stones` | `points` | Writes board-zone blockade map |
| defence solidity (one-shot) | `on_play` | `points` | Connected group + shared adjacency via `shared_stones_effects` |
| tax_enclosure_enemies | `end_of_turn` | `points` | Enclosure scan |
| escalating capture penalty | `on_removed` | `points` | Cross-player |

### Territory control rounds

Per-cell control streaks live in **`state.territory_control_rounds`**. Mult/control stones read this grid in the **mult phase** — no separate placement snapshot hook. See `spec/visual/territory_control_rounds_spec.lua`.

### Shape placement effects

`wall_stone`, `diagonal_group_points`, `line_group_points`:

- Declared **inline on the stone definition only**
- `when = "playing_stones"`, `phase = "points"`
- Run **once** via placement record for that play — not on every board scan

Shared reusable effect tables are for pattern/mult board-wide scans only.

---

## 6. State modeling

### Definitions vs runtime

- **Definitions** (`objects/definitions/*`) are immutable: `effect_name`, `when`, `phase`, parameters, tags.
- **Runtime** on board cells, players, match score bags.

### Energy

```
player.energy
player.energy_max
```

`add_energy` uses `apply` in the points phase like `add_points`.

### Runtime on board cells

| State | On cell |
|-------|---------|
| Delay-reward timer | `survival_rounds_remaining`, `delay_payout` |
| Escalating value | `stored_value` |
| Anti-capture immunity | `immunity_remaining` |
| Placement metadata | `placed_via_play`, `placed_turn_number` |
| Solidity | `solidity`, defence bonus fields |

Removed with the cell — no global timer side maps.

### Board-zone exception

Blockade marks **empty** intersections in a coordinate-keyed map — not on stone instances.

### Defence solidity

`defence_solidity_network` — `when = board_reconcile`, full-board `apply` after topology changes.

---

## 7. Removal and capture

- **Cell-owned state** clears when the cell clears.
- **Remove stones stage** handles physical removal and capture points.
- **Cross-player removal gameplay** (escalating money penalty, bank transfer) — `when = on_removed`, `apply` only.
- Stages must not accumulate `if kind ==` branches; use def-driven rules.

---

## 8. Resolver responsibilities

- Run placement pipeline: commit → remove_stones → territory → points → mult → legality
- Run other beats (`end_of_turn`, `tick`, `on_removed`, `board_reconcile`) with phased `apply`
- Territory recomputation where rules require it
- AI placement scoring mirrors the same `when` / `phase` / placement record as the resolver

The resolver must **not**:

- Use placement hooks (`on_compile`, `on_placement`, …)
- Contain `if effect_name ==` / `if stone_id ==` gameplay branches
- Register empty effect stubs with logic elsewhere

---

## 9. Tests

### Visual specs are frozen scenarios

- **Allowed:** assert-value fixes when behavior genuinely changed
- **Not allowed:** changing boards, hands, or placement sequences without an explicit product doc update

### What to test

- **Unit:** factory shape, helper `apply`, stage modules with seeded boards
- **Integration:** full placement pipeline per stone cluster
- **Visual:** state assertions only

Run affected `spec/unit/*` and `spec/integration/*` when touching stages, phases, or effects.

---

## 10. Migration order (from ADR 0001)

1. **Docs** — this file + ADR (done before code)
2. **Revert** hook-based placement runner and hook fields on factories
3. **Stages** — `remove_stones`, `legality_of_moves`
4. **Pipeline** — wired placement order in resolver
5. **Stone migration** — `apply`-only helpers in small batches
6. **Hygiene** — delete obsolete modules; schema `when`/`phase`; run specs

---

## 11. Reviewer checklist

- [ ] Stone def has `effect_name`, `when`, `phase`
- [ ] Factory delegates to helper; `apply` only (no placement hooks)
- [ ] Capture/removal not implemented as effect hooks
- [ ] Immunity affects legality stage, not placement hook
- [ ] Placement scoring uses placement record when stone removed before points phase
- [ ] No cell-owned state in side maps
- [ ] Visual spec scenarios unchanged (asserts only if needed)
- [ ] Docstrings on factories, helpers, and stages

---

## 12. Anti-patterns

| Anti-pattern | Why it fails |
|--------------|--------------|
| `on_compile` / `on_placement` hooks | Hidden schedule; use stages + phased `apply` |
| `lifecycle` + `macro`/`sub` + phases | Three “when” systems |
| Capture/kamikaze as effect hooks | Belongs in `remove_stones` stage |
| Anti-capture as placement effect | Belongs in legality cache |
| Placement snapshot for mult | Use `territory_control_rounds` |
| Stone logic in `if kind ==` in stages | Def-driven rules only |
| Rewriting visual scenarios during stone work | Breaks regression contract |
