# Gobel documentation

| Document | Description |
|----------|-------------|
| [effects-architecture.md](effects-architecture.md) | **Stone effects:** resolver stages, phased `apply`, state model, test hygiene (see [ADR 0001](adr/0001-stone-effects-stages-and-phases.md)) |
| [capture/scoring.md](capture/scoring.md) | Global capture bonus: `capture_bonus_points_per_stone`, resolve pipeline, test pointers |
| [territory/control-rounds.md](territory/control-rounds.md) | Per-cell territory control streak grid: state, tick rules, `control_territory_stone` payout, test ASCII |
| [ai.md](ai.md) | Bot AI architecture: heuristic placement, strategic goals, shallow MCTS, configuration |
| [../ai/README.md](../ai/README.md) | **Tuning:** `ai/config.lua` — profiles, prescore, MCTS, planner |
| [../AGENTS.md](../AGENTS.md) | **Local agents:** AI Planner vs Code Writer; handoff from cloud |
| [ai-planner-prompt.md](ai-planner-prompt.md) | **Copy-paste prompt** for the local AI Planner agent |
