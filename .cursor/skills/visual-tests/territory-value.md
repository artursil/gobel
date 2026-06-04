# Territory value

Each **empty** cell has a number `territory_value[row][col]`. That number is how much that cell is worth **if you own it** in the territory grid.

Stones do not have a territory value (shown as `#` in tests).

---

## How it is calculated

1. **Start:** every cell on the board is set to **1** (`resolve_round` / `territory.compute_from_board`).
2. **Territory phase:** stone effects on the board can change values on **empty** cells (e.g. tower adds +1 in its corner block; enclosure stone multiplies cells inside your fence). Effects run in game order; later changes stack on top of what is already there.
3. **Ownership** (`b` / `w` / `.`) is computed separately — see [territory-enclosures.md](territory-enclosures.md) and [territory-influence.md](territory-influence.md).
4. **Territory score** for a side = sum of `territory_value[r][c]` on empty cells that side **owns**:

```
black score += value   when territory[r][c] is black-owned empty
```

Unowned empty (`.`) cells are not added to either score, even if they show `2` on the value grid.

---

## Visual test grid (what you must write)

One digit per **empty** cell, `#` per **stone**. Fill the whole 9×9 — no gaps.

| Cell | Expected char |
|------|----------------|
| Empty, value 1 | `1` |
| Empty, value 2–9 | `2` … `9` |
| Stone | `#` |

`assert_territory_values_ascii(g, rows)` compares to `test_helper.territory_weight_ascii(g)`.

Optional: `.` in a row expands to `1` in the helper, but **prefer writing `1` on every empty cell** so the board is readable at a glance.

Optional letters + map (when multiplier comes from params):  
`assert_territory_values_ascii(g, rows, "msg", { values = { d = "2" } })` — token `d` becomes `2` (see `territory_enclosure_spec.lua`).

Ownership and value are **two asserts**: `assert_territory_ascii` then `assert_territory_values_ascii`.

---

## Example 1 — All ones (default board)

Single black stone, no value effects (`scoring_spec.lua`, `territory_scoring_integration_spec.lua` case_01).

**Values** (81 owned black empties × 1 → territory score 81):

```
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 # 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
```

---

## Example 2 — Tower in corner (`T` → +1 in 3×3 block)

`territory_scoring_integration_spec.lua` case_04. Corner tower bumps its 3×3 corner patch from 1 to 2 on empty cells.

**Board:** `T` top-left, `W` mid-right.

**Values:**

```
# 2 2 1 1 1 1 1 1
2 2 2 1 1 1 1 1 1
2 2 2 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 #
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
```

Two towers: case_04_5 in the same file (more `2` patches).

---

## Example 3 — Enclosure stone doubles inside the fence (`N`)

`stones_scoring/territory_enclosure_spec.lua` scenario 1. Ring of `B`, `N` in the hole; cells inside the enclosure get multiplier **2** (default `enclosure_stone_multiplier`).

**Values** (with `TV_OPTS`: `d` = 2, or write `2` directly):

```
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 # # # 1 1 1
1 1 1 # 2 # 1 1 1
1 1 1 # # # 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
1 1 1 1 1 1 1 1 1
```

Outside the ring stays `1`. Same spec has larger pockets, white-only doubling, and stacked multipliers — copy those full grids when extending tests.

---

## Specs to copy from

| File | Shows |
|------|--------|
| `spec/visual/scoring_spec.lua` | Full 9×9 of `1` + `#` |
| `spec/visual/territory_scoring_integration_spec.lua` | Tower `2` patches, score 81 |
| `spec/visual/stones_scoring/territory_enclosure_spec.lua` | `N` / doubled interior |

**See also:** [territory-assignment.md](territory-assignment.md) (who owns each cell).
