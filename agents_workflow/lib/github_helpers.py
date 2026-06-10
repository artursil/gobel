"""GitHub CLI helpers for issue workflow."""

from __future__ import annotations

import json
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PlannedIssue:
    number: int
    title: str
    branch: str
    workflow: str = "tests_exist"
    labels: list[str] | None = None


def _gh_executable() -> str:
    gh = shutil.which("gh")
    if gh is not None:
        return gh
    raise RuntimeError(
        "GitHub CLI (`gh`) not found on PATH. "
        "Install: https://cli.github.com/ then run `gh auth login`."
    )


def _run_gh(args: list[str], *, cwd: Path | None = None) -> str:
    cmd = [_gh_executable(), *args]
    completed = subprocess.run(
        cmd,
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def list_ready_issues(limit: int = 100) -> list[dict]:
    raw = _run_gh(
        [
            "issue",
            "list",
            "--state",
            "open",
            "--label",
            "ready-for-agent",
            "--limit",
            str(limit),
            "--json",
            "number,title,body,labels,comments",
        ]
    )
    return json.loads(raw)


def view_issue(number: int) -> str:
    """Fetch issue text via ``--json`` (default ``gh issue view`` can fail on projectCards)."""
    raw = _run_gh(
        [
            "issue",
            "view",
            str(number),
            "--json",
            "number,title,body,labels",
        ]
    )
    data = json.loads(raw)
    labels = ", ".join(label["name"] for label in data.get("labels", []))
    lines = [
        f"# {data['title']}",
        "",
        f"Issue #{data['number']}",
    ]
    if labels:
        lines.extend(["", f"Labels: {labels}"])
    body = (data.get("body") or "").strip()
    if body:
        lines.extend(["", body])
    return "\n".join(lines)


def issue_title(number: int) -> str:
    """Return the GitHub issue title for ``number``."""
    return _run_gh(["issue", "view", str(number), "--json", "title", "-q", ".title"])


def create_escalation_issue(
    *,
    source_issue: int,
    title: str,
    body: str,
    labels: list[str] | None = None,
) -> int:
    args = [
        "issue",
        "create",
        "--title",
        title,
        "--body",
        body,
        "--json",
        "number",
        "-q",
        ".number",
    ]
    for label in labels or ["agent-escalation"]:
        args.extend(["--label", label])
    number_text = _run_gh(args)
    return int(number_text)


def comment_on_issue(number: int, body: str) -> None:
    _run_gh(["issue", "comment", str(number), "--body", body])


def create_pull_request(
    *,
    title: str,
    body: str,
    head: str,
    base: str,
    cwd: Path | None = None,
) -> str:
    """Open a GitHub pull request and return its URL."""
    return _run_gh(
        [
            "pr",
            "create",
            "--base",
            base,
            "--head",
            head,
            "--title",
            title,
            "--body",
            body,
        ],
        cwd=cwd,
    )


def parse_plan(text: str) -> list[PlannedIssue]:
    import re

    match = re.search(r"<plan>([\s\S]*?)</plan>", text, re.IGNORECASE)
    if not match:
        raise ValueError("Planner did not produce a <plan> block")
    payload = json.loads(match.group(1).strip())
    issues: list[PlannedIssue] = []
    for item in payload.get("issues", []):
        labels = item.get("labels")
        if isinstance(labels, list):
            label_names = [str(x) for x in labels]
        else:
            label_names = []
        issues.append(
            PlannedIssue(
                number=int(item["number"]),
                title=str(item["title"]),
                branch=str(item["branch"]),
                workflow=str(item.get("workflow", "tests_exist")),
                labels=label_names,
            )
        )
    return issues
