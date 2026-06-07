"""Load prompt templates and substitute {{PLACEHOLDER}} variables."""

from __future__ import annotations

import re
from pathlib import Path

_PROMPTS_DIR = Path(__file__).resolve().parent.parent / "prompts"
_PLACEHOLDER = re.compile(r"\{\{([A-Z0-9_]+)\}\}")


def prompts_dir() -> Path:
    return _PROMPTS_DIR


def load_prompt(name: str, variables: dict[str, str] | None = None) -> str:
    """Load ``prompts/{name}.md`` and replace ``{{KEY}}`` placeholders."""
    path = _PROMPTS_DIR / f"{name}.md"
    if not path.is_file():
        raise FileNotFoundError(f"Prompt not found: {path}")
    text = path.read_text(encoding="utf-8")
    if not variables:
        return text

    def replace(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in variables:
            raise KeyError(f"Missing prompt variable: {key} for {name}.md")
        return variables[key]

    return _PLACEHOLDER.sub(replace, text)
