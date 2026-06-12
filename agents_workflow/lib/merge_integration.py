"""Create an integration branch, merge agent branches, push, and open a PR."""

from __future__ import annotations

import subprocess
from pathlib import Path

from lib.agent_runner import run_agent
from lib.github_helpers import PlannedIssue, close_issue, create_pull_request
from lib.prompt_loader import load_prompt


def default_merge_branch_name(issue_numbers: list[int]) -> str:
    """Derive a stable integration branch name from issue numbers."""
    if not issue_numbers:
        return "agent/merge-batch"
    nums = sorted(set(issue_numbers))
    if len(nums) == 1:
        return f"agent/merge-issue-{nums[0]}"
    if nums[-1] - nums[0] + 1 == len(nums):
        return f"agent/merge-issues-{nums[0]}-{nums[-1]}"
    compact = "-".join(str(n) for n in nums)
    if len(compact) > 48:
        return f"agent/merge-issues-{nums[0]}-{nums[-1]}-x{len(nums)}"
    return f"agent/merge-issues-{compact}"


def prepare_merge_branch(repo: Path, branch_name: str, *, base_branch: str) -> None:
    """Check out a fresh integration branch from ``base_branch`` in the main repo."""
    subprocess.run(["git", "fetch", "origin"], cwd=repo, check=True)
    subprocess.run(["git", "checkout", base_branch], cwd=repo, check=True)
    subprocess.run(["git", "pull", "--ff-only", "origin", base_branch], cwd=repo, check=False)
    subprocess.run(["git", "checkout", "-B", branch_name, base_branch], cwd=repo, check=True)
    print(f"[merge] integration branch: {branch_name} (from {base_branch})")


def run_merge_agent(
    issues: list[PlannedIssue],
    repo: Path,
    *,
    merge_branch: str,
    base_branch: str,
) -> None:
    """Run the Merger agent on the current integration branch."""
    if not issues:
        print("No branches to merge.")
        return
    variables = {
        "BRANCHES": "\n".join(f"- {i.branch}" for i in issues),
        "ISSUES": "\n".join(f"- #{i.number}: {i.title}" for i in issues),
        "MERGE_BRANCH": merge_branch,
        "BASE_BRANCH": base_branch,
    }
    prompt = load_prompt("merge-prompt", variables)
    run_agent("Merger", prompt, cwd=repo)


def merge_pr_title(issues: list[PlannedIssue]) -> str:
    """Build a PR title for an agent integration branch."""
    numbers = sorted(i.number for i in issues)
    if not numbers:
        return "Agent merge batch"
    if len(numbers) == 1:
        return f"Agent merge: #{numbers[0]} {issues[0].title}"
    if numbers[-1] - numbers[0] + 1 == len(numbers):
        return f"Agent merge: issues #{numbers[0]}–#{numbers[-1]}"
    joined = ", ".join(f"#{n}" for n in numbers)
    return f"Agent merge: {joined}"


def merge_pr_body(issues: list[PlannedIssue], *, merge_branch: str, base_branch: str) -> str:
    """Build a PR body linking merged agent branches for human review."""
    lines = [
        "## Summary",
        "",
        f"Integrates agent branches into `{merge_branch}` for review before merging to `{base_branch}`.",
        "",
        "## Included branches",
        "",
    ]
    for issue in sorted(issues, key=lambda row: row.number):
        lines.append(f"- `{issue.branch}` — #{issue.number} {issue.title}")
    lines.extend(["", "## Issues", ""])
    for issue in sorted(issues, key=lambda row: row.number):
        lines.append(f"- #{issue.number} {issue.title} (closed after branch merge)")
    lines.extend(
        [
            "",
            "## Review",
            "",
            "Please review test results and implementation, then merge this PR when satisfied.",
        ]
    )
    return "\n".join(lines)


def publish_merge_pr(
    repo: Path,
    issues: list[PlannedIssue],
    *,
    merge_branch: str,
    base_branch: str,
) -> str:
    """Push the integration branch and open a GitHub PR. Returns the PR URL."""
    subprocess.run(["git", "push", "-u", "origin", merge_branch], cwd=repo, check=True)
    pr_url = create_pull_request(
        title=merge_pr_title(issues),
        body=merge_pr_body(issues, merge_branch=merge_branch, base_branch=base_branch),
        head=merge_branch,
        base=base_branch,
        cwd=repo,
    )
    print(f"[merge] PR ready for review: {pr_url}")
    return pr_url


def run_merge_with_pr(
    issues: list[PlannedIssue],
    repo: Path,
    *,
    merge_branch: str,
    base_branch: str,
) -> str:
    """Prepare branch, merge agent branches, push, and create a review PR."""
    prepare_merge_branch(repo, merge_branch, base_branch=base_branch)
    run_merge_agent(issues, repo, merge_branch=merge_branch, base_branch=base_branch)
    return publish_merge_pr(
        repo,
        issues,
        merge_branch=merge_branch,
        base_branch=base_branch,
    )


def run_sequential_merge(
    issues: list[PlannedIssue],
    repo: Path,
    *,
    merge_branch: str,
    base_branch: str,
    close_issues: bool = True,
) -> list[PlannedIssue]:
    """Merge agent branches one at a time and optionally close each issue."""
    if not issues:
        raise ValueError("No issues to merge")

    ordered = sorted(issues, key=lambda row: row.number)
    prepare_merge_branch(repo, merge_branch, base_branch=base_branch)
    merged: list[PlannedIssue] = []

    for issue in ordered:
        print(f"[merge] #{issue.number} ← {issue.branch}")
        run_merge_agent([issue], repo, merge_branch=merge_branch, base_branch=base_branch)
        merged.append(issue)
        if close_issues:
            close_issue(
                issue.number,
                reason=(
                    f"Merged `{issue.branch}` into `{merge_branch}` "
                    f"(integration branch for review against `{base_branch}`)."
                ),
            )
            print(f"[merge] closed #{issue.number}")

    return merged


def run_sequential_merge_with_pr(
    issues: list[PlannedIssue],
    repo: Path,
    *,
    merge_branch: str,
    base_branch: str,
    close_issues: bool = True,
) -> str:
    """Merge sequentially, close issues, then push and open a review PR."""
    merged = run_sequential_merge(
        issues,
        repo,
        merge_branch=merge_branch,
        base_branch=base_branch,
        close_issues=close_issues,
    )
    return publish_merge_pr(
        repo,
        merged,
        merge_branch=merge_branch,
        base_branch=base_branch,
    )
