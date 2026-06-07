#!/usr/bin/env python3
"""parallel_tests_exist: plan → parallel tests_exist → merge."""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

WORKFLOW_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(WORKFLOW_DIR))

from lib.agent_runner import repo_root, run_agent
from lib.git_worktree import ensure_issue_worktree
from lib.github_helpers import PlannedIssue, parse_plan
from lib.prompt_loader import load_prompt
from lib.workflow_common import IssueContext, tests_exist_loop

MAX_PARALLEL = 4


def run_planner(cwd: Path) -> list[PlannedIssue]:
    prompt = load_prompt("plan-prompt", {})
    text = run_agent("Planner", prompt, cwd=cwd).text
    return parse_plan(text)


def run_issue(issue: PlannedIssue, repo: Path) -> tuple[PlannedIssue, bool]:
    worktree = ensure_issue_worktree(repo, issue.branch, issue.number)
    ctx = IssueContext(
        number=issue.number,
        title=issue.title,
        branch=issue.branch,
        visual_spec=False,
    )
    ok = tests_exist_loop(ctx, cwd=worktree)
    return issue, ok


def run_merger(completed: list[PlannedIssue], cwd: Path) -> None:
    if not completed:
        print("No branches to merge.")
        return
    variables = {
        "BRANCHES": "\n".join(f"- {i.branch}" for i in completed),
        "ISSUES": "\n".join(f"- #{i.number}: {i.title}" for i in completed),
    }
    prompt = load_prompt("merge-prompt", variables)
    run_agent("Merger", prompt, cwd=cwd)


def main() -> int:
    repo = repo_root()
    print("=== parallel_tests_exist: planning ===")
    issues = [i for i in run_planner(repo) if i.workflow == "tests_exist"]
    if not issues:
        print("No tests_exist issues to process.")
        return 0

    print(f"Running tests_exist for {len(issues)} issue(s), max parallel {MAX_PARALLEL}")

    completed: list[PlannedIssue] = []
    failed: list[PlannedIssue] = []

    with ThreadPoolExecutor(max_workers=MAX_PARALLEL) as pool:
        futures = {pool.submit(run_issue, issue, repo): issue for issue in issues}
        for future in as_completed(futures):
            issue, ok = future.result()
            if ok:
                completed.append(issue)
                print(f"  ✓ #{issue.number}")
            else:
                failed.append(issue)
                print(f"  ✗ #{issue.number} (escalated or incomplete)")

    print(f"\nCompleted: {len(completed)}, Failed: {len(failed)}")
    if completed:
        print("=== merging (main repo) ===")
        run_merger(completed, repo)

    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
