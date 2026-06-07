"""Git worktree helpers for parallel agent runs."""

from __future__ import annotations

import subprocess
from pathlib import Path


def ensure_issue_worktree(repo_root: Path, branch: str, issue_number: int) -> Path:
    """Return a dedicated worktree path for parallel issue processing."""
    root = repo_root / ".agent-worktrees"
    root.mkdir(exist_ok=True)
    path = root / f"issue-{issue_number}"

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
