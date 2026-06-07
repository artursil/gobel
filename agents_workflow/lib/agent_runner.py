"""Run a Cursor agent with a rendered prompt."""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

from cursor_sdk import Agent, AgentOptions, CursorAgentError, LocalAgentOptions


@dataclass(frozen=True)
class AgentRunResult:
    agent_name: str
    status: str
    text: str
    agent_id: str | None
    run_id: str | None


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


def default_model() -> str:
    return os.environ.get("AGENT_MODEL", "composer-2.5")


def run_agent(
    agent_name: str,
    prompt: str,
    *,
    cwd: Path | None = None,
    model: str | None = None,
) -> AgentRunResult:
    """Launch a one-shot local Cursor agent and return the final assistant text."""
    api_key = os.environ.get("CURSOR_API_KEY")
    if not api_key:
        raise RuntimeError("CURSOR_API_KEY is not set")

    workdir = cwd or repo_root()
    chosen_model = model or default_model()

    try:
        result = Agent.prompt(
            prompt,
            AgentOptions(
                api_key=api_key,
                model=chosen_model,
                local=LocalAgentOptions(cwd=str(workdir)),
            ),
        )
    except CursorAgentError as err:
        print(
            f"[{agent_name}] startup failed: {err.message} "
            f"(retryable={err.is_retryable})",
            file=sys.stderr,
        )
        raise

    if result.status == "error":
        print(f"[{agent_name}] run failed: {result.id}", file=sys.stderr)
        raise RuntimeError(f"Agent run failed: {agent_name}")

    text = result.result or ""
    return AgentRunResult(
        agent_name=agent_name,
        status=result.status,
        text=text,
        agent_id=getattr(result, "agent_id", None),
        run_id=getattr(result, "id", None),
    )
