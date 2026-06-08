# Gobel agent workflows (Cursor SDK + Python)

Orchestrates **test-writer**, **visual-test-writer**, **code-writer**, and **delegator** agents for the Gobel Lua codebase. Inspired by `run.ts` (Sandcastle/Claude Code); adapted for [Cursor SDK](https://cursor.com/docs/sdk/python) local agents.

## Prerequisites

```bash
pip install -r agents_workflow/requirements.txt
```

Create a local secrets file (gitignored):

```bash
cp agents_workflow/secrets.example agents_workflow/secrets
# edit agents_workflow/secrets — set CURSOR_API_KEY from Cursor account settings
```

Also requires:

- `gh` CLI authenticated (`winget install GitHub.cli` on Windows; restart the terminal or run `& "C:\Program Files\GitHub CLI\gh.exe" auth login` if `gh` is not on PATH yet)
- On Windows, agents run via the SDK's **async** bridge (sync local bridge is broken on pipe I/O)
- `busted` for Lua tests
- Git repo with `main` as integration branch

## Agent roles

| Prompt | Role | Edits |
|--------|------|--------|
| `test-writer.md` | Unit/integration specs | `spec/unit`, `spec/integration` |
| `visual-test-writer.md` | Visual specs (`/visual-tests` skill) | `spec/visual` only |
| `code-writer.md` | Production implementation | All except `spec/**`; may raise `<test-concerns>` |
| `delegator.md` | Reviewer / arbiter | Assigns fixes; emits `<delegation>` JSON |

See `prompts/*.md` for full instructions.

## GitHub labels

| Label | Meaning |
|-------|---------|
| `ready-for-agent` | Planner may pick this issue |
| `tests-exist` | Use `tests_exist` workflow (tests already on branch) |
| `visual-spec` | Prefer `visual-test-writer` in `single_feature` |
| `agent-escalation` | Created when a workflow fails after 4 iterations |

Branch naming: **`agent/issue-{number}`**

## Workflows

### `tests_exist.py` — tests on branch, implement only

Loop (max **4** iterations):

1. **code-writer** implements against existing tests
2. **delegator** reviews; validates `<test-concerns>` if present
3. Assigned **test-writer** / **visual-test-writer** fix tests (code-writer never edits tests)
4. Repeat until delegator `status: complete` or escalation issue created

```bash
python agents_workflow/workflows/tests_exist.py --issue 42 --title "Capture bonus"
```

### `single_feature.py` — TDD (tests first)

Loop (max **4** iterations):

1. **test-writer** or **visual-test-writer** (`--visual`) writes tests
2. **code-writer** implements
3. **delegator** + assigned fixes (same as above)

```bash
python agents_workflow/workflows/single_feature.py --issue 42 --visual
```

### `parallel_tests_exist.py`

1. **Planner** (`plan-prompt.md`) → unblocked issues
2. Up to **4** parallel `tests_exist` runs
3. **Merger** merges completed branches

```bash
python agents_workflow/workflows/parallel_tests_exist.py
```

### `parallel_features.py`

Same as above but runs **`single_feature`** per issue.

```bash
python agents_workflow/workflows/parallel_features.py
```

## Delegator output contract

```xml
<delegation>
{
  "status": "complete",
  "remarks": [],
  "implementation_correct": true,
  "test_concerns_valid": true,
  "assignments": [
    {
      "agent": "visual-test-writer",
      "task": "Fix scenario X in spec/visual/...",
      "reason": "Asserts internal effect order; spec says player-visible points only"
    }
  ]
}
</delegation>
```

Parsed by `lib/delegator_parser.py`.

## Escalation

If the loop does not converge in 4 iterations, `lib/workflow_common.py` creates a GitHub issue `[agent-escalation] #N: …` and comments on the source issue.

Parallel runs use **git worktrees** under `.agent-worktrees/issue-{N}` so each issue gets an isolated checkout.

## Legacy

- `run.ts` — original TypeScript/Sandcastle orchestrator (npm/build oriented)
- `prompts/implement_all.md` — monolithic implementer; superseded by **code-writer** for Gobel

## Project docs

- Coding standards: `.cursor/rules/gobel-coding-standards.mdc`
- Stone specs: `mds/STONES_IMPLEMENTATION_ENTRY.md`
- Visual tests skill: `.cursor/skills/visual-tests/SKILL.md`
