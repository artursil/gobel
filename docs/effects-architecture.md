# Stone effects architecture

Normative principles for stone behavior, state modeling, and resolver orchestration. Derived from architecture review of the stones implementation branch (grill-me session, 2026).

**Related:** `.cursor/rules/gobel-coding-standards.mdc`, `mds/OBJECTS.md`, `mds/GAME_RULES.md`

---

## 1. Core model

Every stone behavior is reachable from the stone definition:

```
stone definition
  └─ effects[]: { effect_name, lifecycle, … }
       └─ effect factory (registry)
            └─ helper effect module
                 └─ mutates game state
```

**Navigation rule:** Open a stone in definitions → read its `effect_name` entries → open the factory → open the helper. You should see the full behavior without hunting resolver `if effect_name ==` branches or orphan hooks.

The resolver **schedules when** effects run. It does **not** contain stone-specific gameplay logic.

---

## 2. Three code layers

| Layer | Responsibility | May mutate state? |
|-------|----------------|-------------------|
| **Effect factories** | Map `effect_name` → resolved effect with lifecycle hooks; thin wiring only | No (delegate) |
| **Helper effects** | State-mutating behavior for one `effect_name` or one board event | Yes |
| **Effect helpers** | Pure utilities: coords, dedupe keys, group sizing, tag checks | No |

**Rule of thumb**

- Touches `state.board`, `state.scores`, `state.players`, timers on cells → **helper effect**
- Reusable math/lookup with no side effects → **effect helpers**
- Registry entry wired from stone defs → **effect factory**

Do not put non-factory functions in the effect registry module. Do not put gameplay mutations in effect helpers.

---

## 3. Lifecycle taxonomy

Effects declare **when** they run via `lifecycle` (or equivalent metadata). The resolver runs generic lifecycle runners — never stone-specific dispatch.

| Lifecycle | When invoked | Examples |
|-----------|--------------|----------|
| `placement` | Once when a stone is committed to the board | `add_points`, `add_energy`, `wall_stone`, `blockade_adjacent` (register zones) |
| `board_scan` | Per occupied cell during scoring macro/sub passes | `pattern_x_mult`, `distance_bonus`, territory amplifiers |
| `board_reconcile` | Once after any board topology change (placement, capture, removal) | `defence_solidity_network` |
| `tick` | End of turn or between rounds | delay-reward countdown, blockade duration, immunity decay |
| `on_removed` | When a stone leaves the board — **cross-state gameplay only** | escalating money capture penalty |

### Multi-lifecycle stones

Use **one `effect_name`, multiple hooks** on the resolved effect (e.g. `on_placement`, `on_tick`). The stone definition stays one line; the factory documents all hooks; the helper implements each.

Do not split one stone behavior into multiple `effect_name`s unless they are genuinely independent effects.

### Placement-only shape effects

Effects such as `wall_stone`, `diagonal_group_points`, and `line_group_points`:

- Are declared **inline on the stone definition only** — not in shared reusable effect tables used for board scan
- Use `lifecycle = "placement"`
- Must **not** appear in per-cell board scan passes
- Do not rely on in-apply guards (`placement_coords`, dedupe keys) as a substitute for lifecycle enforcement

Shared effect tables are reserved for effects that apply during **board scan** (e.g. pattern mult on all stones).

---

## 4. State modeling

### Definitions vs runtime

- **Definitions** (`objects/definitions/*`) are immutable identity: `effect_name`, parameters, tags, upgrade tables.
- **Runtime** lives on domain instances: board cells, player records, match-level score bags.

Resolve at use time: static defs via content getters; level/upgrades/tags via instance resolution when placing or scoring.

### Energy

Energy is first-class match state on each player:

```
player.energy       -- current
player.energy_max   -- cap
```

`add_energy` mutates player energy the same way `add_points` mutates score bags. Do not bury energy only inside opaque resource bags without a clear mutator path.

### Runtime state on board cells

Stone-owned runtime state belongs **on the board cell** (stone instance), not in parallel side maps keyed by coordinates.

| State | Lives on cell | Side map? |
|-------|---------------|-----------|
| Delay-reward timer | e.g. `survival_rounds_remaining`, `delay_payout` | No |
| Escalating stored value | `stored_value` | No |
| Anti-capture immunity | `immunity_remaining` | No |
| Placement metadata | `placed_via_play`, `placed_turn_number` | No |
| Intrinsic + bonus solidity | `solidity`, defence bonus fields | No |

When a stone is removed, the cell is cleared → runtime fields disappear. **No global cleanup sweep** is required for cell-owned state.

Tick passes **scan the board** for cells carrying timer/immunity fields and decrement or payout. Do not maintain a separate timer registry unless there is a documented performance exception (none today).

### Board-zone state (exception)

Some effects target **empty cells**, not stone instances. Example: blockade marks orthogonally adjacent empty intersections for N rounds.

That state is **board-zone** (e.g. a blocked-cells map keyed by coordinate). It is not a field on a stone instance. Only this class of effect may use coordinate-keyed maps outside the cell object.

### Defence solidity

`defence_solidity_network` is a **board reconcile** effect:

- Single `apply(state)` reads the full board and writes `solidity` / defence bonus fields on affected cells
- Invoked once after any board change
- Must not use an empty factory stub with logic hidden in resolver-only hooks

---

## 5. Removal and capture

### Cell-owned state

Removing a stone implicitly clears its cell-owned timers, stored values, and immunity. No per-kind cleanup table.

### Stone-specific removal gameplay

When removal affects **other players or global economy** (e.g. escalating money capture penalty), declare `lifecycle = "on_removed"` on that stone definition. The factory wires the helper; the resolver runs `on_removed` for the departing stone.

Do not implement stone-specific removal as `if cell.kind ==` in a global removal module.

### Generic board diff

The resolver may still run a generic board-diff runner for engine concerns (prisoner counts, ko, board commit ordering). That runner must not accumulate stone-specific `kind` branches — only orchestration and board-zone maintenance (e.g. blockade map hygiene).

---

## 6. Resolver responsibilities

The resolver and resolve-round pipeline:

- Run lifecycle runners at the correct moments (placement commit, board reconcile, scoring passes, tick, removal)
- Enforce macro/sub ordering for scoring (`territory` → `points` → `mult`)
- Validate legality (including placement rule exceptions such as kamikaze suicide override in **rules**, not in effect factories)
- Apply board commits and territory recomputation

The resolver must **not**:

- Contain `if effect_name == "…"` or `if stone_id == "…"` gameplay branches
- Call helper modules directly for stone behavior bypassing the effect factory (orphan hooks)
- Register empty effect stubs while implementing behavior elsewhere

### AI read-only mirror

AI placement scoring must use the **same type → round-effect mapping** as the resolver (shared registry/table). Do not maintain parallel `if/elseif` chains on resolved effect types in AI modules.

---

## 7. Tests

### Visual scoring specs are frozen scenarios

Visual specs under the stones scoring suite define **given board, hand, placement sequence**. Agents must not rewrite scenarios during implementation work.

- **Allowed:** assert-value fixes when behavior genuinely changed; formatting cleanup where scenarios are **identical** to the baseline
- **Not allowed:** different initial boards, different stones in hand, different placement coordinates or sequences

When in doubt, diff against `main` and revert scenario changes.

### What to test

- **Unit:** effect factory output, helper pure functions, lifecycle matching, validators
- **Integration:** one end-to-end resolve pass per feature (placement → score / board state)
- **Visual:** state assertions (points, mult, territory, money, energy, solidity, legality) — not pixels

Run affected `spec/unit/*` and `spec/integration/*` when touching effects or resolver scheduling.

---

## 8. Documentation and types

- Every new or changed factory and helper effect exports `--- @param` / `--- @return` docstrings
- Effect definitions use schema-validated shapes (`macro`, `sub`, `lifecycle`, `priority`)
- Balance numbers live in **parameters** modules, not hardcoded in helpers

---

## 9. Anti-patterns (do not repeat)

| Anti-pattern | Why it fails |
|--------------|--------------|
| Empty `apply` + resolver orphan hook | Stone def lies; navigation breaks |
| Side maps for timers/immunity/stored values | Requires global cleanup; duplicates cell state |
| Shape placement effects in shared board-scan tables | Re-fires on every scan; needs fragile dedupe guards |
| Stone logic in `single_game/resolver/*.lua` modules | Hides behavior from effect entry point |
| Rewriting visual spec scenarios during stone work | Loses regression contract |
| `if/elseif` on resolved effect type in AI and resolver separately | Drift between paths |
| Non-factory helpers in the effect registry module | Registry becomes unmaintainable |

---

## 10. Refactor execution order

When correcting a branch that violated these principles:

1. **Tests** — audit visual specs vs baseline; revert scenario drift
2. **State model** — energy on player; cell-owned runtime; drop obsolete side maps
3. **Infrastructure** — lifecycle runners, helper effect layout, shared AI/resolver registries
4. **Stone migration** — small PRs: simple placement → board reconcile → tick → on_removed → complex
5. **Hygiene** — docstrings, delete dead modules, run specs

---

## 11. Quick checklist (reviewers)

- [ ] Stone def lists `effect_name` + `lifecycle`
- [ ] Factory exists and delegates to helper (no empty stub)
- [ ] Helper mutates state; no parallel side map for cell-owned data
- [ ] Resolver has no stone-specific `if effect_name` for this stone
- [ ] Placement-only effects not in board scan
- [ ] Visual spec scenarios unchanged (asserts only if needed)
- [ ] Docstrings on new/changed factories and helpers
- [ ] AI mirror uses shared registry if placement scoring affected
