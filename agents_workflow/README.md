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
| `visual-test-fixer.md` | Fix existing visual specs (`tests_exist` only) | `spec/visual` only; **assert-only** by default |
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
3. Assigned **test-writer** / **visual-test-fixer** fix tests (assert-only for visual specs; code-writer never edits tests)
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

1. **Planner** (`plan-prompt.md`) → unblocked issues, **or** explicit `--process` list
2. Parallel `tests_exist` runs (default max **8**)
3. **Merger** merges into a new integration branch, **pushes**, and **opens a PR** for your review (does not merge to `main` directly)

```bash
# Planner picks ready-for-agent / unblocked tests_exist issues
python agents_workflow/workflows/parallel_tests_exist.py

# Run issues 6-15; PR merges successful completions into agent/merge-issues-6-15
python agents_workflow/workflows/parallel_tests_exist.py --process 6-15

# Run 8-12, then PR-merge a different already-done set
python agents_workflow/workflows/parallel_tests_exist.py --process 8-12 --merge 4-7

# Merge only (no new agent runs) → opens review PR
python agents_workflow/workflows/parallel_tests_exist.py --merge 4-6

# Custom integration branch name
python agents_workflow/workflows/parallel_tests_exist.py --merge 4-6 --merge-branch agent/merge-stones-batch-1
```

Issue lists use ranges and commas: `3-15`, `4,6,8-10`, `4, 6, 8-10`.

Default integration branch: `agent/merge-issues-4-6` (from the `--merge` issue list). PR targets `main` unless `--base-branch` is set. Issues are linked with `Closes #N` in the PR body; they close when **you** merge the PR on GitHub.

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

## Run logs

Each `tests_exist` / `single_feature` run writes artifacts under `.agents/runs/` (gitignored):

```
.agents/runs/tests_exist/issue-4/20260608-143022/
  summary.md              # outcome + index of artifacts
  run.json                # issue/branch metadata
  initial/code-writer.md  # first code-writer output
  iteration-01/
    test-concerns.md      # if code-writer raised <test-concerns>
    delegator.md          # raw delegator output
    delegation.json       # parsed status, remarks, assignments
    assigned/
      visual-test-writer.md
```

The workflow prints `[workflow-log] <path>` at start. Open `summary.md` first, then drill into iteration folders.

## Legacy

- `run.ts` — original TypeScript/Sandcastle orchestrator (npm/build oriented)
- `prompts/implement_all.md` — monolithic implementer; superseded by **code-writer** for Gobel

## Project docs

- Coding standards: `.cursor/rules/gobel-coding-standards.mdc`
- Stone specs: `mds/STONES_IMPLEMENTATION_ENTRY.md`
- Visual tests skill: `.cursor/skills/visual-tests/SKILL.md`
