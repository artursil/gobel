# Territory control rounds

Per-cell history of how long each empty board cell has been continuously controlled by one player. Used by `mult_3_rounds_stone` and maintained by the resolver each full round.

Normative stone payout rules live in `mds/STONES_IMPLEMENTATION_ENTRY.md` §17. This document defines the grid, update rules, test harness, and spec split.

## State

**Field:** `game_state.territory_control_rounds`

**Shape:** dense `9×9` grid: `territory_control_rounds[row][col]` (integer).

Initialized to `0` on every cell at game start.

## Value semantics

| Value | Meaning |
|-------|---------|
| `+N` (`N > 0`) | Black has controlled this empty cell for `N` counted rounds |
| `-N` (`N > 0`) | White has controlled this empty cell for `N` counted rounds |
| `0` | Contested / no man's land, **or** cell currently has a stone |

Contested and no man's land are the same state: both map to `0`. There is no separate contested flag for this grid.

**Sign convention:** positive = black, negative = white.

## Relationship to territory resolution

Each tick reads the current territory owner for **empty** cells from the normal territory resolver (`game_state.territory` after the territory phase). Enclosure topology affects the grid only indirectly — by determining who owns a cell each round.

`mult_3_rounds_stone` reads `territory_control_rounds[row][col]` at **placement time**, before the placed stone occupies the cell.

## Update rules

Run **once per full round** (both players have acted), after territory ownership is known.

For each **empty** cell:

1. **Continuing control (same owner, streak already started):** increment magnitude.
   - Black owns and value is `+N` → `+(N+1)`
   - White owns and value is `-N` → `-(N+1)`

2. **Delayed start (value is `0`, cell newly owned):** stay at `0` for the first round of ownership.
   - Black owns, value `0` → `0`
   - White owns, value `0` → `0`
   - Next full round, if the same side still owns → `+1` or `-1` respectively.

3. **Owner flip (sign was opposite player's):** reset to `0`.
   - Was `+N`, white now owns → `0`
   - Was `-N`, black now owns → `0`
   - Delayed start applies again for the new owner.

4. **Contested / no man's land:** `0`.

**Stone placed on cell:** set that cell to `0` immediately (cell leaves the territory pool).

**Stone removed / captured:** cell becomes empty at `0`; delayed-start rules apply from the next tick based on whoever owns the cell then.

### Example timeline

Black gradually takes a contested cell, holds it, then white flips it:

| Full round | Territory owner | Grid value |
|------------|-----------------|------------|
| 1 | contested | `0` |
| 2 | black (first round) | `0` |
| 3 | black | `+1` |
| 4 | black | `+2` |
| 5 | white (flip) | `0` |
| 6 | white (first round) | `0` |
| 7 | white | `-1` |

## `mult_3_rounds_stone` payout

Parameter: `mult_control_streak_multiplier` (default `2`).

Let `N = abs(territory_control_rounds[row][col])` at placement time.

| Cell value | Placer | `plus_mult` delta |
|------------|--------|-------------------|
| `+N` | black | `+mult_control_streak_multiplier × N` |
| `-N` | white | `+mult_control_streak_multiplier × N` |
| `-N` | black | `-mult_control_streak_multiplier × N` |
| `+N` | white | `-mult_control_streak_multiplier × N` |
| `0` | either | `0` |

**Floor:** after applying the delta, `plus_mult` cannot go below `0`.

**Trigger:** one-time on placement only (no recurring payout).

## Test harness

Control grid is a **separate ASCII layer** from the stone board (`set_board`).

### Functions (`spec/test_helper.lua`)

| Function | Purpose |
|----------|---------|
| `territory_control_rounds_ascii(g)` | Dump grid to row strings |
| `set_territory_control_rounds_ascii(g, rows)` | Seed grid from row strings |
| `assert_territory_control_rounds_ascii(g, expected_rows, context?)` | Assert dump matches expected |
| `complete_full_round(g)` | Pass for `g.to_play` after opponent placement (end-of-round tick when `turn_number` is even) |

`set_territory_control_rounds(g, row, col, n)` is **removed** — seeding goes through ASCII only.

### ASCII format

Explicit signs on every token; all tokens are two characters wide (`+0`, `+3`, `-4`, `##`). Space-separated cells per row, `9` rows.

| Token | Meaning |
|-------|---------|
| `+0` | No control (contested / no man's land) |
| `+N` | Black controlled `N` rounds |
| `-N` | White controlled `N` rounds |
| `##` | Stone on cell (two-char token; dump only; streak not tracked on seed) |

**Seed example:**

```lua
test_helper.set_territory_control_rounds_ascii(g, {
  "+0 +0 +0 +0 +0 +0 +0 +0 +0",
  "+0 +3 +3 +0 +0 -2 -2 +0 +0",
  "+0 +3 +0 +0 +0 -2 +0 +0 +0",
  "+0 +0 +0 +0 +0 +0 +0 +0 +0",
  "+0 +0 +0 +0 +0 +0 +0 +0 +0",
  "+0 +0 +0 +0 +0 +0 +0 +0 +0",
  "+0 +0 +0 +0 +0 +0 +0 +0 +0",
  "+0 +0 +0 +0 +0 +0 +0 +0 +0",
  "+0 +0 +0 +0 +0 +0 +0 +0 +0",
})
```

**Typical stone spec flow:**

```lua
set_board(g, { ". . .", ... })
set_territory_control_rounds_ascii(g, { "+0 +5 +0", ... })
local snap = player_score_snapshot(g, "black")
local expected_delta = S.mult_control_streak_multiplier * 5
place_stone(g, { ". M .", ... })
assert_player_plus_mult_delta(g, "black", snap, expected_delta, "own +5 cell")
```

Use `S.mult_control_streak_multiplier * N` for expected deltas; do not hardcode `2`.

## Spec split

| Spec | Owns |
|------|------|
| `spec/visual/territory_control_rounds_spec.lua` | End-to-end grid maintenance — initial board + seeded control ASCII, one placement, `complete_full_round`, assert final control ASCII. |
| `spec/visual/stones_scoring/17_mult_3_rounds_stone_spec.lua` | Stone payout only — minimal boards, ASCII-seeded control grid, assert `plus_mult` delta. Enclosure topology is **out of scope** (does not affect payout). |
| `spec/unit/territory_control_rounds_spec.lua` | Grid maintenance — delayed start, flip → `0`, stone clears cell, once-per-round tick. Isolated tick helper calls and ASCII seeding. |

### Recommended stone spec scenarios

1. Black on own `+N` → positive `plus_mult`.
2. White on own `-N` → positive `plus_mult`.
3. Black on enemy `-N` → negative delta (floor at `0` when needed).
4. White on enemy `+N` → negative delta.
5. Either on `+0` → no payout.
6. `+1` / `-1` boundary values.
7. One-time trigger — no payout after `advance_rounds`.
8. Multi-zone board — each placement reads only its own cell.

Grid tick scenarios belong in the unit spec, not the stone visual spec.
