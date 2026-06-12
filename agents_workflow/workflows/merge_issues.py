#!/usr/bin/env python3
"""merge_issues: sequentially merge agent branches into an integration branch (Linux/WSL)."""

from __future__ import annotations

import sys
from pathlib import Path

import click

WORKFLOW_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(WORKFLOW_DIR))

from lib.agent_runner import require_linux, repo_root
from lib.issue_spec import planned_issues_from_spec
from lib.merge_integration import (
    default_merge_branch_name,
    run_sequential_merge,
    run_sequential_merge_with_pr,
)


@click.command()
@click.argument(
    "issues_spec",
    metavar="ISSUES",
)
@click.option(
    "--merge-branch",
    default=None,
    help="Integration branch (default: agent/merge-issues-4-6 from issue list).",
)
@click.option(
    "--base-branch",
    default="main",
    show_default=True,
    help="Base branch for the integration branch and PR.",
)
@click.option(
    "--no-close",
    is_flag=True,
    help="Do not close GitHub issues after each successful merge.",
)
@click.option(
    "--no-pr",
    is_flag=True,
    help="Skip push and review PR after all merges complete.",
)
def main(
    issues_spec: str,
    merge_branch: str | None,
    base_branch: str,
    no_close: bool,
    no_pr: bool,
) -> None:
    """Merge agent/issue-N branches one at a time into a new integration branch."""
    require_linux()
    repo = repo_root()
    issues = planned_issues_from_spec(issues_spec, workflow="merge")
    branch = merge_branch or default_merge_branch_name([issue.number for issue in issues])
    close_issues = not no_close

    print(f"=== merge_issues: {issues_spec} → {branch} (base {base_branch}) ===")
    print(f"=== {len(issues)} branches, sequential merge ===")

    if no_pr:
        run_sequential_merge(
            issues,
            repo,
            merge_branch=branch,
            base_branch=base_branch,
            close_issues=close_issues,
        )
        print(f"=== merge complete (no PR); branch {branch} ===")
        raise SystemExit(0)

    pr_url = run_sequential_merge_with_pr(
        issues,
        repo,
        merge_branch=branch,
        base_branch=base_branch,
        close_issues=close_issues,
    )
    print(f"=== merge complete: {pr_url} ===")
    raise SystemExit(0)


if __name__ == "__main__":
    main()
