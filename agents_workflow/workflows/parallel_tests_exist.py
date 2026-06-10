#!/usr/bin/env python3
"""parallel_tests_exist: plan → parallel tests_exist → merge PR."""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import click

WORKFLOW_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(WORKFLOW_DIR))

from lib.agent_runner import repo_root
from lib.git_worktree import ensure_issue_worktree
from lib.github_helpers import PlannedIssue, parse_plan
from lib.issue_spec import planned_issues_from_spec
from lib.merge_integration import default_merge_branch_name, run_merge_with_pr
from lib.workflow_common import VISUAL_TEST_FIXER_PROMPT, IssueContext, tests_exist_loop

MAX_PARALLEL = 8


def run_planner(cwd: Path) -> list[PlannedIssue]:
    from lib.agent_runner import run_agent
    from lib.prompt_loader import load_prompt

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
    ok = tests_exist_loop(ctx, cwd=worktree, visual_test_prompt=VISUAL_TEST_FIXER_PROMPT)
    return issue, ok


def run_process_batch(
    issues: list[PlannedIssue],
    repo: Path,
    *,
    max_parallel: int,
) -> tuple[list[PlannedIssue], list[PlannedIssue]]:
    """Run ``tests_exist`` for each issue; return (completed, failed)."""
    print(f"Running tests_exist for {len(issues)} issue(s), max parallel {max_parallel}")
    completed: list[PlannedIssue] = []
    failed: list[PlannedIssue] = []

    with ThreadPoolExecutor(max_workers=max_parallel) as pool:
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
    return completed, failed


def resolve_merge_issues(
    merge_spec: str | None,
    completed: list[PlannedIssue],
) -> list[PlannedIssue] | None:
    if merge_spec is not None:
        return planned_issues_from_spec(merge_spec)
    if completed:
        return completed
    return None


@click.command()
@click.option(
    "--process",
    "-p",
    "process_spec",
    default=None,
    help="Issues to run tests_exist on (e.g. 6-15 or 4,6,8-10). Omit to use the planner.",
)
@click.option(
    "--merge",
    "-m",
    "merge_spec",
    default=None,
    help="Issues to merge (e.g. 4-6). Defaults to successful --process completions.",
)
@click.option(
    "--merge-branch",
    default=None,
    help="Integration branch for the review PR (default: agent/merge-issues-4-6 from merge list).",
)
@click.option(
    "--base-branch",
    default="main",
    show_default=True,
    help="Base branch for the integration branch and PR.",
)
@click.option(
    "--max-parallel",
    default=MAX_PARALLEL,
    show_default=True,
    help="Maximum parallel tests_exist workers.",
)
def main(
    process_spec: str | None,
    merge_spec: str | None,
    merge_branch: str | None,
    base_branch: str,
    max_parallel: int,
) -> None:
    """Run parallel tests_exist workflows and open a review PR for merged branches."""
    repo = repo_root()
    completed: list[PlannedIssue] = []
    failed: list[PlannedIssue] = []

    if process_spec is None and merge_spec is None:
        print("=== parallel_tests_exist: planning ===")
        process_issues = [i for i in run_planner(repo) if i.workflow == "tests_exist"]
        if not process_issues:
            print("No tests_exist issues to process.")
            raise SystemExit(0)
        completed, failed = run_process_batch(process_issues, repo, max_parallel=max_parallel)
    elif process_spec is not None:
        process_issues = planned_issues_from_spec(process_spec)
        print(f"=== parallel_tests_exist: process {process_spec} ===")
        completed, failed = run_process_batch(process_issues, repo, max_parallel=max_parallel)
    else:
        print("=== parallel_tests_exist: merge only ===")

    merge_issues = resolve_merge_issues(merge_spec, completed)
    if merge_issues:
        branch = merge_branch or default_merge_branch_name([i.number for i in merge_issues])
        print(f"=== merging into {branch} → PR against {base_branch} ===")
        run_merge_with_pr(
            merge_issues,
            repo,
            merge_branch=branch,
            base_branch=base_branch,
        )

    raise SystemExit(0 if not failed else 1)


if __name__ == "__main__":
    main()
