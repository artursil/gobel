"""Parse structured output from the delegator agent."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from typing import Literal

AgentRole = Literal["code-writer", "test-writer", "visual-test-writer", "none"]

_DELEGATION_TAG = re.compile(r"<delegation>([\s\S]*?)</delegation>", re.IGNORECASE)
_TEST_CONCERNS_TAG = re.compile(r"<test-concerns>([\s\S]*?)</test-concerns>", re.IGNORECASE)


@dataclass(frozen=True)
class DelegationAssignment:
    agent: AgentRole
    task: str
    reason: str


@dataclass
class DelegationResult:
    status: Literal["complete", "needs_work"]
    remarks: list[str] = field(default_factory=list)
    assignments: list[DelegationAssignment] = field(default_factory=list)
    implementation_correct: bool | None = None
    test_concerns_valid: bool | None = None
    raw_text: str = ""


def _coerce_agent(value: str) -> AgentRole:
    normalized = value.strip().lower().replace("_", "-")
    allowed: set[str] = {"code-writer", "test-writer", "visual-test-writer", "none"}
    if normalized not in allowed:
        raise ValueError(f"Unknown agent role in delegation: {value}")
    return normalized  # type: ignore[return-value]


def parse_delegation(text: str) -> DelegationResult:
    """Extract ``<delegation>{json}</delegation>`` from agent output."""
    match = _DELEGATION_TAG.search(text)
    if not match:
        return DelegationResult(
            status="needs_work",
            remarks=["Delegator did not emit a <delegation> block."],
            raw_text=text,
        )

    payload = json.loads(match.group(1).strip())
    status = payload.get("status", "needs_work")
    if status not in ("complete", "needs_work"):
        raise ValueError(f"Invalid delegation status: {status}")

    assignments: list[DelegationAssignment] = []
    for item in payload.get("assignments", []):
        assignments.append(
            DelegationAssignment(
                agent=_coerce_agent(str(item.get("agent", "none"))),
                task=str(item.get("task", "")).strip(),
                reason=str(item.get("reason", "")).strip(),
            )
        )

    remarks = [str(r).strip() for r in payload.get("remarks", []) if str(r).strip()]

    return DelegationResult(
        status=status,
        remarks=remarks,
        assignments=[a for a in assignments if a.agent != "none" and a.task],
        implementation_correct=payload.get("implementation_correct"),
        test_concerns_valid=payload.get("test_concerns_valid"),
        raw_text=text,
    )


def parse_test_concerns(text: str) -> str | None:
    """Extract optional ``<test-concerns>`` block from code-writer output."""
    match = _TEST_CONCERNS_TAG.search(text)
    if not match:
        return None
    body = match.group(1).strip()
    return body or None
