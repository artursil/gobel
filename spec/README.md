# Gobel test suite

## Fast default (~15–18s target)

```bash
busted spec/unit spec/integration spec/visual
```

Runs unit, visual, and non-gated integration specs. Slow AI integration specs are **pending** unless `INTEGRATION=1`.

## Full suite (~35s+)

Includes slow AI bot, dual-suggest, MCTS, turn planner, and placement heuristic integration specs.

```bash
INTEGRATION=1 busted
```

Windows PowerShell:

```powershell
$env:INTEGRATION=1; busted
```

## Gated integration specs

Set `INTEGRATION=1` to run these (otherwise reported as pending). Each file calls `spec_helper.require_integration()` at the top of its `describe` block and returns early when gated out.

| Spec | Notes |
|------|-------|
| `integration/ai_bot_spec.lua` | Full PVC bot loop (~20s) |
| `integration/ai_dual_suggest_spec.lua` | Dual ranker + placement pool (~11s) |
| `integration/ai_turn_planner_spec.lua` | MAIN phase planner |
| `integration/ai_placement_heuristic_spec.lua` | Capture vs fill heuristic |
| `integration/ai_mcts_spec.lua` | MCTS + evaluator |
| `integration/ai_mcts_dual_spec.lua` | MCTS dual stone pool |

Fast integration specs (always run): `resolver_spec`, `stone_metadata_spec`, `temporary_stance_turn_spec`, `vertical_slice_spec`, `territory_runtime_spec`, `effect_conditions_integration_spec`, `card_ui_flow_spec`, `integration_match_loop_spec`, `stone_popup_flow_spec`.

## Debug output

Territory/scoring ASCII dumps when:

```bash
INTEGRATION_DEBUG=1 busted spec/integration/...
```

See `spec_helper.integration_debug_enabled()` in `spec/spec_helper.lua`.

## CI

No GitHub workflow is configured yet. When CI is added, run the fast command by default; use a nightly or manual job with `INTEGRATION=1` for the full suite.
