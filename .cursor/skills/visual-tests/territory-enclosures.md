# Enclosures — how empty cells get an owner

Code: `single_game/resolver/enclosure.lua` → `detect_regions_and_ownership(b, tiles)`.

In a full game, **enclosure beats influence**: if a hole is yours by enclosure, distance to stones no longer decides that cell (`territory.lua`). When writing tests, check enclosure with `regions_ascii` before the full territory grid.

## What you see in tests

| Char | Meaning |
|------|---------|
| `B` / `W` | Stone |
| `b` / `w` | Empty cell assigned to black / white **by enclosure** |
| `.` | Empty, enclosure did not pick a sole owner |

You draw the board with `.` `B` `W` only. Run detection; lowercase `b`/`w` is the answer.

---

## Why walls matter (without the full algorithm)

Enclosure does **not** ask “who has more stones touching this empty square?”

It asks: **did one side build a fence around a pocket of empty space?** That fence is a **wall** — boundary stones plus the empty cells trapped inside. The engine finds walls first, then decides which empty cells belong to which side.

If no valid wall covers a cell, enclosure leaves it unowned (`.`). Influence or other rules may still claim it later in the full territory pass.

**How walls are found** (passable flood, open vs closed holes, proper boundary, inside vs outside): see **[territory-walls.md](territory-walls.md)**.

---

## “Probe as black” / “probe as white”

The same board is analyzed **twice**:

1. **Black’s turn to “look for fences”** — imagine empty space and **white** stones are walkable, but **black** stones are solid walls. Which closed pockets are ringed only by **black** stones? Those become candidate **black** walls.
2. **White’s turn** — the roles swap: walk through empty and **black** stones; **white** stones block you. Pockets ringed only by **white** stones become **white** walls.

So a white stone sitting on black’s ring does **not** count as part of black’s fence (Example C below). Black and white each get their own list of walls; enclosure then reconciles overlaps (two fences fighting for the same cell).

---

## Pipeline

```
stones on board
  → (1) group touching empty cells (region_id)
  → (2) find walls (black pass, then white pass)  →  territory-walls.md
  → (3) each trapped cell: which wall wins if several apply?
  → (4) each empty group: one owner only if all its cells agree
```

### Step 1 — Empty groups

Orthogonal flood through **empty cells only**. Neighbouring empties share one `region_id` (even a single `.` is its own group).

### Step 2 — Walls

`extract_walls` — details and ASCII in **[territory-walls.md](territory-walls.md)**.

### Step 3 — Who owns each trapped cell?

Each wall marks its **inside** cells with an owner and pocket size. When two walls disagree on one cell:

| Situation | Result |
|-----------|--------|
| Only one wall covers the cell | That side |
| Smallest pockets tie on size, same side | That side |
| Smallest pockets tie on size, **different** sides | `.` |
| **Nested** — one pocket fully inside the other | Smaller pocket wins |
| **Crossing** — pockets overlap, neither contains the other | `.` for shared cells |

**Nested vs crossing** (both pockets claim the same empty cell):

- **Nested** — black has a 1-cell hole, white has a 5-cell hole around it. Black wins the inner cell (smaller pocket).
- **Crossing** — black and white pockets share some interior cells, but neither interior fully swallows the other. Those shared cells get **no** enclosure owner (`.`).

Code calls this *walls cross*: overlap exists, but neither `inside` set contains the other.

### Step 4 — Whole empty group

Every empty tile in one `region_id` must get the **same** owner from step 3. If any cell in that connected empty group gets `B` and another gets `W`, the **whole group** stays `.` in `regions_ascii` — even cells that had a clear sole wall on their own.

Cells in different empty groups are decided independently. Example E below: `(5,4)` is `b` while `(4,5)` is `.` because a white stone at `(5,5)` splits them into separate empty groups.

---

## Example A — Ring around one hole (works)

**Board:**

```
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . B B B . . .
. . . B . B . . .
. . . B B B . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
```

Black’s probe finds a closed pocket; only black stones touch it → center is inside a black wall → **`b`**.

```
. . . B B B . . .
. . . B b B . . .
. . . B B B . . .
```

(`spec/visual/enclosure_integration_spec.lua` — black center enclosure)

---

## Example B — Hole open to the edge (fails)

```
. . . B . . . . .
. B B B . . . . .
. . . . . . . . .
```

The empty area under the arc can “escape” to the board edge → **not a closed pocket** → no wall → stays `.` (no `b`).

---

## Example C — Opponent stone on the ring (black still claims)

```
. . . W B B . . .
. . . B . B . . .
. . . B B B . . .
```

When **probing as black**, only **black** stones on the ring count as the fence. The `W` is ignored for black’s wall; the hole is still sealed by black → **`b`**.

```
. . . W B B . . .
. . . B b B . . .
. . . B B B . . .
```

---

## Example D — Two sides, two pockets

Same shape, one stone moved — fixture **#6** vs **#9** in `enclosure_integration_spec.lua`: one gets a white pocket (`w`), the other a black pocket (`b`). Good template for “one placement flips enclosure”.

---

## Example E — Crossing enclosures on one board

Minimal crop of fixture **#13** in `enclosure_integration_spec.lua` — only the **black 6-cell pocket** and the **white 8-cell pocket** that fight over one cell. The full fixture adds more pockets, gaps, and edge cases on the same shape.

**Board** (stones in rows 1–6 only):

```
. . . W . . W . .
. . . W . . W . .
. . W B B B W . .
. W B W . W B . .
. W B . W . B . .
. . W B B B . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
```

**Enclosure-only result** (`regions_ascii`):

```
. . . W w w W . .
. . . W w w W . .
. . W B B B W . .
. W B W . W B . .
. W B b W b B . .
. . W B B B . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
```

**What to read off this board:**

| Cell | Why |
|------|-----|
| `(5,4)`, `(5,6)` | Only the **black** pocket (size 6) lists these empties → `b`. The white pocket (size 8) does **not** include them. |
| `(4,5)` | **Crossing** — both pockets list this cell, but neither interior fully contains the other → `.`. |

The white stone at `(5,5)` splits `(4,5)` and `(5,4)` into **different empty groups**, so `(5,4)` can be `b` while `(4,5)` stays `.` from crossing.

Smaller pocket size only wins when pockets are **nested** or **disjoint**. **Crossing cancels** enclosure for the shared cell.

**Full fixture:** `enclosure_integration_spec.lua` fixture **#13** / `territory_integration_spec.lua` case 05 extend this with side pockets, fence gaps, and open edge regions. That file asserts the **full** territory grid (enclosure first, then influence for cells left as `.`).

---

