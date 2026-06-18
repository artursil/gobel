"""Batch execution for multi-issue workflows (parallel or sequential)."""

from __future__ import annotations

from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from lib.github_helpers import PlannedIssue


def _record_result(
    issue: PlannedIssue,
    ok: bool,
    completed: list[PlannedIssue],
    failed: list[PlannedIssue],
) -> None:
    if ok:
        completed.append(issue)
        print(f"  ✓ #{issue.number}")
    else:
        failed.append(issue)
        print(f"  ✗ #{issue.number} (escalated or incomplete)")


def run_issues_sequential(
    issues: list[PlannedIssue],
    repo: Path,
    run_one: Callable[[PlannedIssue, Path], tuple[PlannedIssue, bool]],
    *,
    label: str,
) -> tuple[list[PlannedIssue], list[PlannedIssue]]:
    """Run ``run_one`` for each issue in order; return (completed, failed)."""
    print(f"Running {label} for {len(issues)} issue(s), sequentially")
    completed: list[PlannedIssue] = []
    failed: list[PlannedIssue] = []

    for issue in issues:
        print(f"\n--- #{issue.number}: {issue.title} ---")
        finished_issue, ok = run_one(issue, repo)
        _record_result(finished_issue, ok, completed, failed)

    print(f"\nCompleted: {len(completed)}, Failed: {len(failed)}")
    return completed, failed


def run_issues_parallel(
    issues: list[PlannedIssue],
    repo: Path,
    run_one: Callable[[PlannedIssue, Path], tuple[PlannedIssue, bool]],
    *,
    label: str,
    max_parallel: int,
) -> tuple[list[PlannedIssue], list[PlannedIssue]]:
    """Run ``run_one`` across a thread pool; return (completed, failed)."""
    workers = max(1, min(max_parallel, len(issues)))
    print(f"Running {label} for {len(issues)} issue(s), max parallel {workers}")
    completed: list[PlannedIssue] = []
    failed: list[PlannedIssue] = []

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(run_one, issue, repo): issue for issue in issues}
        for future in as_completed(futures):
            issue = futures[future]
            print(f"\n--- finished #{issue.number}: {issue.title} ---")
            finished_issue, ok = future.result()
            _record_result(finished_issue, ok, completed, failed)

    print(f"\nCompleted: {len(completed)}, Failed: {len(failed)}")
    return completed, failed


def run_issues_batch(
    issues: list[PlannedIssue],
    repo: Path,
    run_one: Callable[[PlannedIssue, Path], tuple[PlannedIssue, bool]],
    *,
    label: str,
    max_parallel: int,
) -> tuple[list[PlannedIssue], list[PlannedIssue]]:
    """Run issues in parallel when ``max_parallel > 1``, otherwise sequentially."""
    if max_parallel <= 1:
        return run_issues_sequential(issues, repo, run_one, label=label)
    return run_issues_parallel(issues, repo, run_one, label=label, max_parallel=max_parallel)
