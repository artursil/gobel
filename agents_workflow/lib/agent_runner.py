"""Run a Cursor agent with a rendered prompt."""

from __future__ import annotations

import asyncio
import os
import sys
from dataclasses import dataclass
from pathlib import Path

from cursor_sdk import Agent, AgentOptions, CursorAgentError, LocalAgentOptions
from cursor_sdk.types import RunResult


@dataclass(frozen=True)
class AgentRunResult:
    agent_name: str
    status: str
    text: str
    agent_id: str | None
    run_id: str | None


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


def secrets_path() -> Path:
    return Path(__file__).resolve().parent.parent / "secrets"


def read_secrets() -> dict[str, str]:
    """Read ``agents_workflow/secrets`` (gitignored KEY=VALUE lines)."""
    path = secrets_path()
    if not path.is_file():
        return {}
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        key, sep, value = stripped.partition("=")
        if not sep:
            continue
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def default_model() -> str:
    secrets = read_secrets()
    return os.environ.get("AGENT_MODEL") or secrets.get("AGENT_MODEL") or "composer-2.5"


def _agent_options(api_key: str, model: str, workdir: Path) -> AgentOptions:
    return AgentOptions(
        api_key=api_key,
        model=model,
        local=LocalAgentOptions(cwd=str(workdir)),
    )


async def _run_agent_async(
    prompt: str,
    *,
    api_key: str,
    model: str,
    workdir: Path,
) -> RunResult:
    """Use async bridge on Windows; sync ``select()`` cannot watch pipe stderr."""
    from cursor_sdk.asyncio import AsyncAgent, AsyncClient

    async with await AsyncClient.launch_bridge(
        workspace=str(workdir),
        local=LocalAgentOptions(cwd=str(workdir)),
    ) as client:
        return await AsyncAgent.prompt(
            prompt,
            _agent_options(api_key, model, workdir),
            client=client,
        )


def _run_agent_sync(
    prompt: str,
    *,
    api_key: str,
    model: str,
    workdir: Path,
) -> RunResult:
    return Agent.prompt(prompt, _agent_options(api_key, model, workdir))


def run_agent(
    agent_name: str,
    prompt: str,
    *,
    cwd: Path | None = None,
    model: str | None = None,
) -> AgentRunResult:
    """Launch a one-shot local Cursor agent and return the final assistant text."""
    secrets = read_secrets()
    api_key = os.environ.get("CURSOR_API_KEY") or secrets.get("CURSOR_API_KEY")
    if not api_key:
        raise RuntimeError(
            "CURSOR_API_KEY is not set. "
            f"Copy agents_workflow/secrets.example to {secrets_path()} and add your key."
        )

    workdir = cwd or repo_root()
    chosen_model = model or default_model()

    try:
        if sys.platform == "win32":
            result = asyncio.run(
                _run_agent_async(
                    prompt,
                    api_key=api_key,
                    model=chosen_model,
                    workdir=workdir,
                )
            )
        else:
            result = _run_agent_sync(
                prompt,
                api_key=api_key,
                model=chosen_model,
                workdir=workdir,
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
