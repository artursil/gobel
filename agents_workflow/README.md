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

Also requires (**Linux/WSL only** — do not run workflows from Windows PowerShell):

- WSL2 with the repo at a Linux path (e.g. `/mnt/c/Users/.../gobel` or `~/gobel`)
- **Git operations from WSL only** — commit, merge, and `merge_issues.py` from a WSL shell. The repo uses LF line endings (see root `.gitattributes`); mixing Windows PowerShell git with WSL causes phantom `M` files on every file.
- `gh` CLI authenticated (`gh auth login`)
- `busted` for Lua tests
- Git repo with `main` as integration branch

```bash
# WSL example
cd /mnt/c/Users/Artur/Documents/gobel
python3 -m venv .venv && source .venv/bin/activate
pip install -r agents_workflow/requirements.txt
cp agents_workflow/secrets.example agents_workflow/secrets
```

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
2. **Parallel** `tests_exist` runs (default max **8**; set `--max-parallel 1` for sequential)

```bash
# Planner picks ready-for-agent / unblocked tests_exist issues
python agents_workflow/workflows/parallel_tests_exist.py

# Run issues 6-15
python agents_workflow/workflows/parallel_tests_exist.py --process 6-15

# Fresh start: remove worktrees + local agent/issue-N branches, then process
python agents_workflow/workflows/parallel_tests_exist.py --process 8-15 --clear
```

When processing finishes, the script prints a suggested `merge_issues.py` command for successful issues.

### `parallel_features.py`

Same batch pattern but runs **`single_feature`** per issue in parallel (default max **4**).

```bash
python agents_workflow/workflows/parallel_features.py --process 6-10
```

### `merge_issues.py`

Sequentially merges `agent/issue-N` branches into a new integration branch — **one branch at a time**, closing each GitHub issue after its merge succeeds, then **pushes** and **opens a review PR** (does not merge to `main` directly).

```bash
# Merge issues 4-25 into agent/merge-issues-4-25, close each issue, open PR
python agents_workflow/workflows/merge_issues.py 4-25

# Non-contiguous list
python agents_workflow/workflows/merge_issues.py 4,6,8-10

# Custom integration branch
python agents_workflow/workflows/merge_issues.py 4-6 --merge-branch agent/merge-stones-batch-1

# Merge locally without opening a PR
python agents_workflow/workflows/merge_issues.py 4-6 --no-pr

# Keep issues open (e.g. for a dry run)
python agents_workflow/workflows/merge_issues.py 4-6 --no-close
```

Issue lists use ranges and commas: `3-15`, `4,6,8-10`, `4, 6, 8-10`.

Default integration branch: `agent/merge-issues-4-6` (from the issue list). PR targets `main` unless `--base-branch` is set.

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

Batch runs use **git worktrees** under `.agent-worktrees/issue-{N}` so each issue gets an isolated checkout. Issues run in parallel via a thread pool (Linux/WSL only).

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
