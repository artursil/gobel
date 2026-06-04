# Territory assignment (who owns each empty cell)

Empty cells get an owner **B** (black) or **W** (white). Stones stay **B** / **W** (uppercase). Unowned empty = `.` in territory grids.

**Precedence** (first match wins) — see `single_game/resolver/territory.lua` `resolve_empty_tile`:

1. **Override** — control stone / effects that set `override_owner` on a cell
2. **Enclosure** — fully surrounded region → region owner
3. **Influence** — nearest stone (Manhattan distance); ties → more nearest stones; still tied → neutral `.`

## Territory grid legend (visual tests)

| Char | Meaning |
|------|---------|
| `B` / `W` | Stone on board |
| `b` / `w` | Empty cell owned by black / white |
| `.` | Empty, no owner (tie / no influence) |

Use `assert_territory_ascii(g, { ... })` after `set_board` / `place_stone` — see `spec/test_helper.lua`.

## Subtopics

- [Enclosures](territory-enclosures.md) — sealed regions
- [Walls](territory-walls.md) — wall detection (enclosure boundaries)
- [Influence](territory-influence.md) — distance assignment when not enclosed

## Copy boards from existing specs

Reuse ASCII from these files; adapt one row at a time rather than inventing layouts:

| Topic | Spec file |
|-------|-----------|
| Influence cases 01–05 | `spec/visual/territory_integration_spec.lua`, `territory_ascii_integration_spec.lua` |
| Enclosure regions | `spec/visual/enclosure_integration_spec.lua` |
| Walls | `spec/visual/wall_detection_spec.lua` |
| Enclosure + scoring stones | `spec/visual/stones_scoring/territory_enclosure_spec.lua` |
| Tower corner value + territory | `spec/visual/territory_scoring_integration_spec.lua` |
