# Gobel — agent roles

This repo supports a **two-agent workflow** for bot AI work:

| Role | Who | Does | Does not |
|------|-----|------|----------|
| **AI Planner** | Local agent with `@gobel-ai-planner` skill or `gobel-ai-planner` rule | Architecture, specs, task breakdowns, implementation briefs for the coder | Edit `ai/`, game logic, or tests |
| **Code Writer** | Default implementer agent | Implements briefs, runs tests, commits | Redesign architecture without planner sign-off |

## Quick start (local)

1. Open this repo on your machine (same branch as cloud work if continuing a PR).
2. Start a **new Agent** chat.
3. Invoke the planner skill: mention **gobel-ai-planner** or add rule **Gobel AI planner** (`.cursor/rules/gobel-ai-planner.mdc`).
4. Say what you want planned (e.g. “spec ensemble placement” or “review normal profile vs M.placement defaults”).
5. Copy the planner’s **Implementation brief** into a **separate** Agent chat (no planner rule) to implement.

Planner knowledge lives in:

- **`docs/ai-planner-prompt.md`** — **complete copy-paste prompt** for a new Agent chat (start here)
- `.cursor/skills/gobel-ai-planner/SKILL.md` — same context as a Cursor skill
- `.cursor/rules/gobel-ai-planner.mdc` — same role constraints in Cursor rules
- `docs/ai.md`, `ai/README.md` — canonical architecture (code writer should align with these)

## Handoff from cloud

Cloud agents push branches/PRs; the planner skill does **not** auto-sync chat history. After pull, tell the local planner: branch name, PR link, and what phase or constraint changed.
