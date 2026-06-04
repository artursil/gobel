# Influence

Used when an empty cell has **no** control override and **no** enclosure owner. Code: `resolve_regular_owner` in `single_game/resolver/territory.lua`.

Territory grid: `B`/`W` = stone, `b`/`w` = empty owned by black/white, `.` = empty, nobody owns (neutral).

---

## How it is calculated

For each empty cell:

1. Find the **nearest black stone** and **nearest white stone** (Manhattan steps: |Δrow| + |Δcol|).
2. Some stones reduce their distance (e.g. lieutenant adds a **bonus** subtracted from distance).
3. **Closer side wins** (`b` or `w`).
4. **Same distance** → side with **more** stones tied for nearest wins.
5. **Still tied** → `.` (no owner from influence).

Enclosure and overrides run first; influence only fills what they leave open.

---

## ASCII examples

Copied from `spec/visual/territory_integration_spec.lua` (board → territory). Use `assert_territory_ascii` / `helper.territory_map(b, "regional")`.

### Example 1 — One stone owns the board (case 01)

**Board:**

```
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . B . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
```

**Territory** (every empty cell is closer to `B` than to any white stone):

```
b b b b b b b b b
b b b b b b b b b
b b b b b b b b b
b b b b b b b b b
b b b b B b b b b
b b b b b b b b b
b b b b b b b b b
b b b b b b b b b
b b b b b b b b b
```

---

### Example 2 — Black top-left, white bottom-left (case 02)

**Board:**

```
. . . . . . . . .
. B . . . . . . .
. . . . . . . . .
W . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
```

**Territory:**

```
b b b b b b b b b
b B b b b b b b b
w b b b b b b b b
W w w w w w w w w
w w w w w w w w w
w w w w w w w w w
w w w w w w w w w
w w w w w w w w w
w w w w w w w w w
```

Each empty cell goes to whichever stone is fewer steps away; the middle band splits roughly along the diagonal between `B` and `W`.

---

### Example 3 — Both sides press; neutral `.` where tied (case 04)

**Board:**

```
B B . . W . . . .
B . . W . . . . .
. W W . . . . . .
W W . . . B . . .
. . . . W W . . .
. . . B . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
```

**Territory:**

```
B B w w W w w w w
B w w W w w w w w
w W W w w b b b b
W W w w . B b b b
w w w . W W w w w
w . b B . w w w w
w . b b . w w w w
w . b b . w w w w
w . b b . w w w w
```

The `.` cells (e.g. row 4, column 5) are equidistant with no tie-break — influence assigns no owner. Nearby cells still pick `b` or `w` from the nearest stone.

---

### Example 4 — Ring + corner stones (case 03)

Enclosure also affects this board; shown here as the **full** territory grid from the spec (influence fills cells enclosure does not).

**Board:**

```
W . . . . . . . W
. . . . . . . . .
. . . B B B . . .
. . . B . B . . .
. . . B B B . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
W . . . . . . . W
```

**Territory:**

```
W w w b b b w w W
w w b b b b b w w
w b b B B B b b w
. b b B b B b b .
b b b B B B b b b
w b b b b b b b w
w w b b b b b w w
w w w b b b w w w
W w w w w w w w w W
```

Compare with [territory-enclosures.md](territory-enclosures.md) for the same ring in **enclosure-only** (`regions_ascii`) tests.

**More boards:** case 05 in the same spec (enclosure + influence combined). Source: `spec/visual/territory_ascii_integration_spec.lua` (cases 01–04 duplicate).
