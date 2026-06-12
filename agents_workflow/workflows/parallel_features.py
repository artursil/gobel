#!/usr/bin/env python3
"""parallel_features: plan → batch single_feature (Linux/WSL)."""

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
from lib.prompt_loader import load_prompt
from lib.workflow_common import IssueContext, single_feature_loop

MAX_PARALLEL = 4


def run_planner(cwd: Path) -> list[PlannedIssue]:
    prompt = load_prompt("plan-prompt", {})
    text = run_agent("Planner", prompt, cwd=cwd).text
    return parse_plan(text)


def is_visual(issue: PlannedIssue) -> bool:
    if issue.labels and any("visual" in label for label in issue.labels):
        return True
    return "visual" in issue.title.lower()


def run_issue(issue: PlannedIssue, repo: Path) -> tuple[PlannedIssue, bool]:
    worktree = ensure_issue_worktree(repo, issue.branch, issue.number)
    ctx = IssueContext(
        number=issue.number,
        title=issue.title,
        branch=issue.branch,
        visual_spec=is_visual(issue),
    )
    ok = single_feature_loop(ctx, cwd=worktree)
    return issue, ok


@click.command()
@click.option(
    "--process",
    "-p",
    "process_spec",
    default=None,
    help="Issues to run single_feature on (e.g. 6-15). Omit to use the planner.",
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
    help="Maximum parallel single_feature workers (use 1 for sequential).",
)
def main(
    process_spec: str | None,
    clear: bool,
    max_parallel: int,
) -> None:
    """Run single_feature workflows in batch."""
    require_linux()
    repo = repo_root()
    completed: list[PlannedIssue] = []
    failed: list[PlannedIssue] = []
    process_issues: list[PlannedIssue]

    if process_spec is None:
        print("=== parallel_features: planning ===")
        process_issues = [i for i in run_planner(repo) if i.workflow == "single_feature"]
        if not process_issues:
            print("No single_feature issues to process.")
            raise SystemExit(0)
    else:
        process_issues = planned_issues_from_spec(process_spec, workflow="single_feature")
        print(f"=== parallel_features: process {process_spec} ===")

    if clear:
        clear_issues(repo, process_issues)

    completed, failed = run_issues_batch(
        process_issues,
        repo,
        run_issue,
        label="single_feature",
        max_parallel=max_parallel,
    )

    print(f"=== done: {len(completed)} succeeded, {len(failed)} failed ===")
    if completed:
        numbers = ", ".join(str(issue.number) for issue in completed)
        print(f"To merge: python agents_workflow/workflows/merge_issues.py {numbers}")

    raise SystemExit(0 if not failed else 1)


if __name__ == "__main__":
    main()
