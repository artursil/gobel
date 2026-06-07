# Capture scoring

Global points awarded when a stone placement removes one or more enemy stones. Independent of which stone type was placed.

Normative global rule summary lives in `mds/STONES_IMPLEMENTATION_ENTRY.md` (Global Conventions). Stone-specific capture mechanics (e.g. `capture_stone` mixed surround) are documented per stone in that entry file.

## Parameter

| Name | Module | Default |
|------|--------|---------|
| `capture_bonus_points_per_stone` | `objects/parameters/stones.lua` | `3` |

## Formula

On a legal stone placement:

```
capture_points = capture_bonus_points_per_stone × enemy_stones_removed
```

`enemy_stones_removed` is the count of opponent stones removed by that placement (same count used for prisoners).

## When it applies

- **Yes:** standard Go capture from stone placement (`rules.try_play` capture count).
- **Yes:** any stone type (`stone_basic`, `stone_power`, `wall`, `capture_stone`, …).
- **Per stone:** capturing a connected group of N stones awards `N × capture_bonus_points_per_stone`.

## When it does not apply

- No enemy stones removed on the placement (`captures = 0`).
- Pass, card effects, or other non-placement board changes.
- Kamikaze self-removal (not an enemy capture).
- Failed `capture_stone` placement with no eligible target (no stones removed).

## Resolve pipeline

1. `compile_place_stone_events` computes `captures` from `rules.try_play`.
2. When `captures > 0`, an `add_points` effect is appended (`playing_stones` → `points` sub-phase).
3. Score UI emits a separate points score event for the capture bonus (`source = "capture"`), distinct from stone placement payout.

## Tests

| File | Coverage |
|------|----------|
| `spec/visual/capture_bonus_spec.lua` | End-to-end placement captures across stone types |
| `spec/unit/capture_bonus_spec.lua` | Compile-time bonus injection contract |
| `spec/visual/stones_scoring/19_capture_stone_spec.lua` | Bonus expectations where captures occur (mechanics scenarios may remain red until `capture_stone` is implemented) |
