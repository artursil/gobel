#!/usr/bin/env python3
"""single_feature: tests first, then implement (TDD loop)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

WORKFLOW_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(WORKFLOW_DIR))

from lib.agent_runner import require_linux, repo_root
from lib.workflow_common import (
    add_issue_args,
    checkout_branch,
    issue_context_from_args,
    single_feature_loop,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Gobel single_feature workflow")
    add_issue_args(parser)
    args = parser.parse_args()
    require_linux()
    ctx = issue_context_from_args(args)
    cwd = repo_root()

    print(f"single_feature #{ctx.number} on {ctx.branch} (visual={ctx.visual_spec})")
    checkout_branch(ctx.branch, cwd=cwd)

    ok = single_feature_loop(ctx, cwd=cwd)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
