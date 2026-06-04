# Walls — finding fences around empty pockets

Code: `single_game/resolver/enclosure.lua` → `extract_walls(board)`.

Enclosure uses walls to know **which empty cells sit inside whose fence**. Overview and examples of final `b`/`w`/`.` ownership: **[territory-enclosures.md](territory-enclosures.md)**.

A **wall** record has:

- `owner` — `"B"` or `"W"`
- `boundary_fields` — stone cells that form the fence
- `inside_fields` — empty cells trapped on the enclosed side

---

## Wall debug ASCII (`wall_detection_spec.lua`)

Shows **one** wall at a time (not the whole board ownership):

| Char | Meaning |
|------|---------|
| `B` / `W` | Fence stone (wall owner’s color) |
| `b` / `w` | Empty **inside** this wall |
| `.` | Everything else |

---

## How extraction works

The same steps run **twice**: first hunting **black** fences, then **white** fences. Results from both passes go into one `walls` list.

Below, the steps are written for the **black pass**. For the **white pass**, swap the colors (walk on black stones, treat white stones as solid fence).

### 1. Walk the area you can stand on (black pass)

Flood-fill blobs of cells:

- **Empty** — yes  
- **White stones** — yes (you may walk on them)  
- **Black stones** — no (black is the fence; you cannot walk onto it)

Each blob is “everything reachable without stepping on black.”

### 2. Throw away open blobs

If the blob touches the board edge in a way that means it is **not a sealed room**:

- touches **3 or more** sides of the board, or  
- touches **two opposite** sides (top+bottom or left+right),

then it is **open** (connected to the outside) → **no wall** from this blob.

### 3. Collect the black fence stones

For a **closed** blob, take every **black** stone next to the blob (orthogonal or diagonal). That is the candidate boundary.

If that boundary also includes white stones, discard this blob (not a pure black fence).

### 4. Keep only real “loop” boundaries

Boundary stones may split into separate chunks. Each chunk is tested: if blocking those stones would cut the board into **exactly two** regions, it is a **proper** fence loop.

Among proper chunks, take the **largest** boundary. The **inside** of the wall is the **smaller** of those two regions (the pocket, not the rest of the board).

### 5. Dedupe

Identical boundaries are stored once.

Then repeat §1–§5 for the **white pass** (walk on black, fences are white only).

---

## Example 1 — White U-shape (closed pocket)

**Board** (`spec/visual/wall_detection_spec.lua`):

```
. . . . . . . . .
. . . W W . . . .
. . W . . W . . .
. . W . . W . . .
. . . W . W . . .
. . . . W . . . .
```

Largest wall found (white fence, empty inside):

```
. . . W W . . . .
. . W w w W . . .
. . W w w W . . .
. . . W w W . . .
. . . . W . . . .
```

The `w` cells are **inside_fields**; uppercase `W` is **boundary_fields**.

---

## Example 2 — Many walls; “biggest” for display

Same file — `white triangle top-left` board has several white walls. Tests pick the wall with largest `inside + boundary` count for the ASCII snapshot. Use `debug_dump_all_walls` when `INTEGRATION_DEBUG` is on to print every wall.

**Board snippet:**

```
. . . B . . . W .
B B B B . . W . .
. . . . . W . . .
W W W W W . . . .
```

One extracted white wall (interior marked `w`):

```
w w w w w w w W .
w w w w w w W . .
w w w w w W . . .
W W W W W . . . .
```

Copy full boards from `wall_detection_spec.lua`.

---

## Example 3 — Black ring → same geometry as enclosure Example A

**Board:**

```
. . . B B B . . .
. . . B . B . . .
. . . B B B . . .
```

**Black probe:** passable blob = center `.`; boundary = ring of `B`; inside = center.

**White probe:** can walk through black stones; blob is huge and open to edges → no white wall for that hole.

That is why enclosure can mark the center `b` even though the ring is black-only — see **[territory-enclosures.md](territory-enclosures.md)** Example A.

---

## Example 4 — Open arc → no wall

```
. . . B . . . . .
. B B B . . . . .
```

Passable blob under the arc reaches the top/left edge → open → **no wall** from step 2. Enclosure leaves those empties `.`.

---

## Relation to enclosure

```
extract_walls(board)  →  list of walls
       ↓
assign owners to inside_fields (conflict rules)
       ↓
detect_regions_and_ownership  →  regions_ascii b / w / .
```

Debugging tip: if `regions_ascii` is wrong, check whether a wall exists at all (`wall_detection_spec` style) before tuning conflict rules.

---

## Other specs to copy

| File | Use |
|------|-----|
| `spec/visual/wall_detection_spec.lua` | Wall ASCII, multi-wall boards |
| `spec/visual/enclosure_integration_spec.lua` | Same shapes, final `b`/`w`/`.` |
| `spec/visual/stones_scoring/x_plus_wall_spec.lua` | `W` = wall **stone** type on board |

**See also:** [territory-enclosures.md](territory-enclosures.md)
