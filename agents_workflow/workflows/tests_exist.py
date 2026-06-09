#!/usr/bin/env python3
"""tests_exist: implement against existing tests (code-writer → delegator loop)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

WORKFLOW_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(WORKFLOW_DIR))

from lib.agent_runner import repo_root
from lib.workflow_common import (
    VISUAL_TEST_FIXER_PROMPT,
    add_issue_args,
    checkout_branch,
    issue_context_from_args,
    tests_exist_loop,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Gobel tests_exist workflow")
    add_issue_args(parser)
    args = parser.parse_args()
    ctx = issue_context_from_args(args)
    cwd = repo_root()

    print(f"tests_exist #{ctx.number} on {ctx.branch}")
    checkout_branch(ctx.branch, cwd=cwd)

    ok = tests_exist_loop(ctx, cwd=cwd, visual_test_prompt=VISUAL_TEST_FIXER_PROMPT)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
