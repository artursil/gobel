#!/usr/bin/env python3
"""parallel_tests_exist: plan → batch tests_exist → merge PR (Linux/WSL)."""

from __future__ import annotations

import sys
from pathlib import Path

import click

WORKFLOW_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(WORKFLOW_DIR))

from lib.agent_runner import require_linux, repo_root, run_agent
from lib.batch_runner import run_issues_batch
from lib.git_worktree import clear_issues, ensure_issue_worktree
from lib.github_helpers import PlannedIssue, parse_plan
from lib.issue_spec import planned_issues_from_spec
from lib.merge_integration import default_merge_branch_name, run_merge_with_pr
from lib.prompt_loader import load_prompt
from lib.workflow_common import VISUAL_TEST_FIXER_PROMPT, IssueContext, tests_exist_loop

MAX_PARALLEL = 8


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
    ok = tests_exist_loop(ctx, cwd=worktree, visual_test_prompt=VISUAL_TEST_FIXER_PROMPT)
    return issue, ok


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
    "--clear",
    is_flag=True,
    help="Delete worktrees and local agent branches for process issues before running.",
)
@click.option(
    "--max-parallel",
    default=MAX_PARALLEL,
    show_default=True,
    help="Maximum parallel tests_exist workers (use 1 for sequential).",
)
def main(
    process_spec: str | None,
    merge_spec: str | None,
    merge_branch: str | None,
    base_branch: str,
    clear: bool,
    max_parallel: int,
) -> None:
    """Run tests_exist workflows in batch and open a review PR for merged branches."""
    require_linux()
    repo = repo_root()
    completed: list[PlannedIssue] = []
    failed: list[PlannedIssue] = []
    process_issues: list[PlannedIssue] | None = None

    if process_spec is None and merge_spec is None:
        print("=== parallel_tests_exist: planning ===")
        process_issues = [i for i in run_planner(repo) if i.workflow == "tests_exist"]
        if not process_issues:
            print("No tests_exist issues to process.")
            raise SystemExit(0)
    elif process_spec is not None:
        process_issues = planned_issues_from_spec(process_spec)
        print(f"=== parallel_tests_exist: process {process_spec} ===")
    else:
        print("=== parallel_tests_exist: merge only ===")

    if clear:
        if not process_issues:
            raise SystemExit("--clear requires a process list (--process) or planner mode")
        clear_issues(repo, process_issues)

    if process_issues is not None:
        completed, failed = run_issues_batch(
            process_issues,
            repo,
            run_issue,
            label="tests_exist",
            max_parallel=max_parallel,
        )

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
