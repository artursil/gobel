# AI package

Bot logic for PVC (`game.versus_bot`). See [../docs/ai.md](../docs/ai.md) for architecture, MCTS flow, and scoring weights.

## Tunables

| Field | Effect |
|-------|--------|
| `game.ai_strategy` | `"heuristic"` (default) or `"random"`. `"mcts"` is not a separate strategy module—it aliases `heuristic` and only affects whether placement MCTS runs (see `mcts_config.should_run`). |
| `game.ai_difficulty` | `"easy"` / `"normal"` / `"hard"` → presets in `mcts_config.DIFFICULTY` (`enabled`, `iterations`, `max_rollout_depth`, `exploration_c`). |
| `game.ai_mcts` | Per-field overrides on the difficulty preset. **Required on the match for MCTS** when `ai_strategy == "heuristic"` (PVC sets this in `game.new`). |
| `game.ai_mcts.enabled` | `false` → heuristic placement only (Phase 1 behavior). |
| `game.ai_mcts.iterations` | Playout budget per placement decision (`0` also disables search). |

PVC defaults (`game.new`): `ai_strategy = "heuristic"`, `ai_difficulty = "normal"`, `ai_mcts` with **MCTS off** for sub-second moves. Set `ai_difficulty = "hard"` for budgeted fast MCTS (~100ms cap, 20 iterations).

**Latency:** Full `territory.compute_from_board` per call is expensive. Normal/hard-off paths use at most **8** full evals per placement (cheap prescore first). MCTS rollouts use **fast** eval (stone/wall counts only).

## Disable MCTS (debug / weak bot)

```lua
g.ai_mcts = { enabled = false, iterations = 0 }
-- or
g.ai_difficulty = "easy"
```

Omit `game.ai_mcts` entirely on a custom match to keep pure heuristic placement with no search.

## Territory debug

Set `config.TERRITORY_DEBUG = true` to re-enable `[Territory]` prints from `single_game/resolver/territory.lua` and `enclosure.lua`. Default is `false`.
