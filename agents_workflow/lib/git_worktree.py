"""Git worktree helpers for parallel agent runs."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from lib.github_helpers import PlannedIssue
from lib.workflow_common import branch_for_issue


def issue_worktree_path(repo_root: Path, issue_number: int) -> Path:
    return repo_root / ".agent-worktrees" / f"issue-{issue_number}"


def clear_issue_agent_state(repo_root: Path, issue_number: int, branch: str) -> None:
    """Remove the issue worktree and delete the local agent branch."""
    path = issue_worktree_path(repo_root, issue_number)
    if path.exists() or path.is_symlink():
        subprocess.run(
            ["git", "worktree", "remove", "--force", str(path)],
            cwd=repo_root,
            check=False,
        )
    if path.exists():
        shutil.rmtree(path, ignore_errors=True)
    subprocess.run(["git", "worktree", "prune"], cwd=repo_root, check=False)
    subprocess.run(["git", "branch", "-D", branch], cwd=repo_root, check=False)
    print(f"[clear] #{issue_number}: removed worktree and branch {branch}")


def clear_issues(repo_root: Path, issues: list[PlannedIssue]) -> None:
    """Remove worktrees and local branches for each planned issue."""
    if not issues:
        return
    print(f"=== clearing {len(issues)} issue worktree(s) and branch(es) ===")
    for issue in issues:
        clear_issue_agent_state(repo_root, issue.number, issue.branch)


def clear_issue_numbers(repo_root: Path, issue_numbers: list[int]) -> None:
    """Remove worktrees and local branches by issue number."""
    issues = [
        PlannedIssue(
            number=number,
            title=f"Issue #{number}",
            branch=branch_for_issue(number),
        )
        for number in issue_numbers
    ]
    clear_issues(repo_root, issues)


def ensure_issue_worktree(repo_root: Path, branch: str, issue_number: int) -> Path:
    """Return a dedicated worktree path for parallel issue processing."""
    root = repo_root / ".agent-worktrees"
    root.mkdir(exist_ok=True)
    path = issue_worktree_path(repo_root, issue_number)

    if (path / ".git").exists() or (path / ".git").is_file():
        subprocess.run(["git", "-C", str(path), "checkout", branch], check=False)
        subprocess.run(["git", "-C", str(path), "pull", "--ff-only"], check=False)
        return path

    subprocess.run(["git", "fetch", "origin"], cwd=repo_root, check=False)
    remote_ref = f"origin/{branch}"
    has_remote = (
        subprocess.run(
            ["git", "rev-parse", "--verify", remote_ref],
            cwd=repo_root,
            capture_output=True,
        ).returncode
        == 0
    )
    if has_remote:
        subprocess.run(
            ["git", "worktree", "add", "-B", branch, str(path), remote_ref],
            cwd=repo_root,
            check=True,
        )
    else:
        subprocess.run(
            ["git", "worktree", "add", "-B", branch, str(path)],
            cwd=repo_root,
            check=True,
        )
    return path
