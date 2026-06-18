"""Parse issue number lists like ``3-15`` or ``4,6,8-10``."""

from __future__ import annotations

import re

from lib.github_helpers import PlannedIssue, issue_title
from lib.workflow_common import branch_for_issue

_TOKEN = re.compile(r"^\s*(\d+)\s*(?:-\s*(\d+)\s*)?$")


def parse_issue_spec(spec: str) -> list[int]:
    """Expand an issue spec into sorted unique issue numbers.

    Examples: ``3-15``, ``4,6,8-10``, ``4, 6, 8-10``.
    """
    stripped = spec.strip()
    if not stripped:
        raise ValueError("Issue spec is empty")

    numbers: set[int] = set()
    for part in stripped.split(","):
        token = part.strip()
        if not token:
            continue
        match = _TOKEN.match(token)
        if not match:
            raise ValueError(f"Invalid issue spec segment: {part!r}")
        start = int(match.group(1))
        end_text = match.group(2)
        if end_text is None:
            numbers.add(start)
            continue
        end = int(end_text)
        if end < start:
            raise ValueError(f"Invalid issue range (end < start): {token}")
        numbers.update(range(start, end + 1))

    if not numbers:
        raise ValueError(f"No issue numbers parsed from: {spec!r}")
    return sorted(numbers)


def planned_issues_from_spec(
    spec: str,
    *,
    workflow: str = "tests_exist",
) -> list[PlannedIssue]:
    """Build ``PlannedIssue`` rows for explicit issue numbers."""
    return [
        PlannedIssue(
            number=number,
            title=issue_title(number),
            branch=branch_for_issue(number),
            workflow=workflow,
        )
        for number in parse_issue_spec(spec)
    ]
