"""Persist agent outputs and parsed concerns/delegations for workflow runs."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from lib.agent_runner import repo_root
from lib.delegator_parser import DelegationResult


def agents_log_root() -> Path:
    return repo_root() / ".agents" / "runs"


@dataclass
class WorkflowRunLogger:
    """Write per-run artifacts under ``.agents/runs/{workflow}/issue-{N}/{timestamp}/``."""

    workflow: str
    issue_number: int
    branch: str
    title: str
    run_dir: Path
    started_at: datetime = field(default_factory=datetime.now)
    _events: list[str] = field(default_factory=list)

    @classmethod
    def start(cls, workflow: str, *, issue_number: int, branch: str, title: str) -> WorkflowRunLogger:
        """Create a new run directory and print its path."""
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        run_dir = agents_log_root() / workflow / f"issue-{issue_number}" / stamp
        run_dir.mkdir(parents=True, exist_ok=False)
        logger = cls(
            workflow=workflow,
            issue_number=issue_number,
            branch=branch,
            title=title,
            run_dir=run_dir,
        )
        logger._write(
            "run.json",
            json.dumps(
                {
                    "workflow": workflow,
                    "issue_number": issue_number,
                    "title": title,
                    "branch": branch,
                    "started_at": logger.started_at.isoformat(timespec="seconds"),
                },
                indent=2,
            )
        )
        print(f"[workflow-log] {run_dir}")
        return logger

    def _write(self, relative: str, content: str) -> Path:
        path = self.run_dir / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def log_agent(
        self,
        agent: str,
        text: str,
        *,
        phase: str,
        extra_context: str = "",
    ) -> None:
        """Save raw agent output."""
        rel = f"{phase}/{agent}.md"
        header = f"# {agent} ({phase})\n\n"
        if extra_context and extra_context != "(none)":
            header += f"## Extra context\n\n{extra_context}\n\n## Output\n\n"
        self._write(rel, header + text)
        self._events.append(f"- `{phase}` **{agent}** → `{rel}`")

    def log_test_concerns(self, concerns: str, *, iteration: int) -> None:
        """Save parsed ``<test-concerns>`` from code-writer."""
        rel = f"iteration-{iteration:02d}/test-concerns.md"
        self._write(rel, f"# Test concerns (iteration {iteration})\n\n{concerns}\n")
        self._events.append(f"- iteration {iteration}: **test concerns** → `{rel}`")

    def log_delegation(
        self,
        raw_text: str,
        result: DelegationResult,
        *,
        iteration: int,
    ) -> None:
        """Save delegator raw output and parsed delegation JSON."""
        prefix = f"iteration-{iteration:02d}"
        self._write(f"{prefix}/delegator.md", f"# Delegator (iteration {iteration})\n\n{raw_text}\n")
        payload = {
            "status": result.status,
            "remarks": result.remarks,
            "implementation_correct": result.implementation_correct,
            "test_concerns_valid": result.test_concerns_valid,
            "assignments": [
                {"agent": a.agent, "task": a.task, "reason": a.reason}
                for a in result.assignments
            ],
        }
        self._write(f"{prefix}/delegation.json", json.dumps(payload, indent=2))
        assignment_summary = ", ".join(a.agent for a in result.assignments) or "none"
        self._events.append(
            f"- iteration {iteration}: **delegator** status=`{result.status}` "
            f"assignments=[{assignment_summary}]"
        )

    def finalize(self, *, success: bool, escalated: bool = False) -> None:
        """Write a human-readable run summary."""
        outcome = "complete" if success else ("escalated" if escalated else "incomplete")
        lines = [
            f"# {self.workflow} — issue #{self.issue_number}",
            "",
            f"- **Title:** {self.title}",
            f"- **Branch:** `{self.branch}`",
            f"- **Started:** {self.started_at.isoformat(timespec='seconds')}",
            f"- **Outcome:** {outcome}",
            f"- **Log dir:** `{self.run_dir}`",
            "",
            "## Artifacts",
            "",
            *self._events,
            "",
        ]
        self._write("summary.md", "\n".join(lines))
