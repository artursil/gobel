"""Shared iteration loop for Gobel agent workflows."""

from __future__ import annotations

import argparse
import subprocess
from dataclasses import dataclass
from pathlib import Path

from lib.agent_runner import repo_root, run_agent
from lib.delegator_parser import DelegationResult, parse_delegation, parse_test_concerns
from lib.github_helpers import comment_on_issue, create_escalation_issue, view_issue
from lib.prompt_loader import load_prompt

MAX_ITERATIONS = 4


@dataclass(frozen=True)
class IssueContext:
    number: int
    title: str
    branch: str
    visual_spec: bool


def branch_for_issue(number: int) -> str:
    return f"agent/issue-{number}"


def checkout_branch(branch: str, *, cwd: Path) -> None:
    subprocess.run(["git", "fetch", "origin"], cwd=cwd, check=False)
    if subprocess.run(["git", "checkout", branch], cwd=cwd, capture_output=True).returncode == 0:
        return
    remote_ref = f"origin/{branch}"
    if (
        subprocess.run(["git", "rev-parse", "--verify", remote_ref], cwd=cwd, capture_output=True).returncode
        == 0
    ):
        subprocess.run(["git", "checkout", "-B", branch, remote_ref], cwd=cwd, check=True)
        return
    subprocess.run(["git", "checkout", "-B", branch], cwd=cwd, check=True)


def issue_variables(ctx: IssueContext) -> dict[str, str]:
    return {
        "ISSUE_NUMBER": str(ctx.number),
        "ISSUE_TITLE": ctx.title,
        "BRANCH": ctx.branch,
        "ISSUE_BODY": view_issue(ctx.number),
    }


def run_code_writer(ctx: IssueContext, *, cwd: Path, extra: str = "") -> str:
    variables = issue_variables(ctx)
    variables["EXTRA_CONTEXT"] = extra or "(none)"
    prompt = load_prompt("code-writer", variables)
    return run_agent("Code Writer", prompt, cwd=cwd).text


def run_test_writer(ctx: IssueContext, *, cwd: Path, extra: str = "") -> str:
    variables = issue_variables(ctx)
    variables["EXTRA_CONTEXT"] = extra or "(none)"
    prompt = load_prompt("test-writer", variables)
    return run_agent("Test Writer", prompt, cwd=cwd).text


def run_visual_test_writer(ctx: IssueContext, *, cwd: Path, extra: str = "") -> str:
    variables = issue_variables(ctx)
    variables["EXTRA_CONTEXT"] = extra or "(none)"
    prompt = load_prompt("visual-test-writer", variables)
    return run_agent("Visual Test Writer", prompt, cwd=cwd).text


def run_delegator(
    ctx: IssueContext,
    *,
    cwd: Path,
    code_writer_output: str,
    test_writer_output: str = "",
    iteration: int,
) -> DelegationResult:
    variables = issue_variables(ctx)
    variables["ITERATION"] = str(iteration)
    variables["CODE_WRITER_OUTPUT"] = code_writer_output
    variables["TEST_WRITER_OUTPUT"] = test_writer_output or "(no test-writer output this iteration)"
    prompt = load_prompt("delegator", variables)
    text = run_agent("Delegator", prompt, cwd=cwd).text
    return parse_delegation(text)


def run_assigned_agents(
    delegation: DelegationResult,
    ctx: IssueContext,
    *,
    cwd: Path,
) -> dict[str, str]:
    outputs: dict[str, str] = {}
    for assignment in delegation.assignments:
        extra = f"{assignment.reason}\n\n{assignment.task}"
        if assignment.agent == "code-writer":
            outputs["code-writer"] = run_code_writer(ctx, cwd=cwd, extra=extra)
        elif assignment.agent == "test-writer":
            outputs["test-writer"] = run_test_writer(ctx, cwd=cwd, extra=extra)
        elif assignment.agent == "visual-test-writer":
            outputs["visual-test-writer"] = run_visual_test_writer(ctx, cwd=cwd, extra=extra)
    return outputs


def escalate(ctx: IssueContext, delegation: DelegationResult, *, iterations: int) -> int:
    body = (
        f"Agent workflow failed to converge after {iterations} iterations.\n\n"
        f"Source issue: #{ctx.number}\n"
        f"Branch: `{ctx.branch}`\n\n"
        "## Delegator remarks\n"
        + "\n".join(f"- {r}" for r in delegation.remarks)
        + "\n\n## Last assignments\n"
        + "\n".join(
            f"- **{a.agent}**: {a.task} ({a.reason})" for a in delegation.assignments
        )
        + "\n\nPlease resolve manually or split the issue."
    )
    number = create_escalation_issue(
        source_issue=ctx.number,
        title=f"[agent-escalation] #{ctx.number}: {ctx.title}",
        body=body,
    )
    comment_on_issue(
        ctx.number,
        f"Agent workflow escalated after {iterations} iterations. Follow-up: #{number}",
    )
    return number


def tests_exist_loop(ctx: IssueContext, *, cwd: Path) -> bool:
    """Tests already on branch: code-writer → delegator → assigned fixes (loop)."""
    code_output = run_code_writer(ctx, cwd=cwd)
    test_output = ""
    last_delegation: DelegationResult | None = None

    for iteration in range(1, MAX_ITERATIONS + 1):
        print(f"\n=== tests_exist iteration {iteration}/{MAX_ITERATIONS} (#{ctx.number}) ===")

        concerns = parse_test_concerns(code_output)
        if concerns:
            print("[code-writer] raised test concerns")

        last_delegation = run_delegator(
            ctx,
            cwd=cwd,
            code_writer_output=code_output,
            test_writer_output=test_output,
            iteration=iteration,
        )

        if last_delegation.status == "complete":
            print(f"[delegator] complete for #{ctx.number}")
            return True

        fix_outputs = run_assigned_agents(last_delegation, ctx, cwd=cwd)
        if "code-writer" in fix_outputs:
            code_output = fix_outputs["code-writer"]
        if "test-writer" in fix_outputs:
            test_output = fix_outputs["test-writer"]
        if "visual-test-writer" in fix_outputs:
            test_output = fix_outputs["visual-test-writer"]

    escalate(ctx, last_delegation or DelegationResult(status="needs_work"), iterations=MAX_ITERATIONS)
    return False


def single_feature_loop(ctx: IssueContext, *, cwd: Path) -> bool:
    """Tests first → code-writer → delegator → assigned fixes (loop)."""
    if ctx.visual_spec:
        test_output = run_visual_test_writer(ctx, cwd=cwd)
    else:
        test_output = run_test_writer(ctx, cwd=cwd)

    code_output = run_code_writer(ctx, cwd=cwd, extra=test_output)
    last_delegation: DelegationResult | None = None

    for iteration in range(1, MAX_ITERATIONS + 1):
        print(f"\n=== single_feature iteration {iteration}/{MAX_ITERATIONS} (#{ctx.number}) ===")

        last_delegation = run_delegator(
            ctx,
            cwd=cwd,
            code_writer_output=code_output,
            test_writer_output=test_output,
            iteration=iteration,
        )

        if last_delegation.status == "complete":
            print(f"[delegator] complete for #{ctx.number}")
            return True

        fix_outputs = run_assigned_agents(last_delegation, ctx, cwd=cwd)
        if "code-writer" in fix_outputs:
            code_output = fix_outputs["code-writer"]
        if "test-writer" in fix_outputs:
            test_output = fix_outputs["test-writer"]
        if "visual-test-writer" in fix_outputs:
            test_output = fix_outputs["visual-test-writer"]

    escalate(ctx, last_delegation or DelegationResult(status="needs_work"), iterations=MAX_ITERATIONS)
    return False


def add_issue_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--issue", type=int, required=True, help="GitHub issue number")
    parser.add_argument("--title", type=str, default="", help="Issue title (optional)")
    parser.add_argument(
        "--branch",
        type=str,
        default="",
        help="Git branch (default: agent/issue-{number})",
    )
    parser.add_argument(
        "--visual",
        action="store_true",
        help="Use visual-test-writer instead of test-writer (single_feature only)",
    )


def issue_context_from_args(args: argparse.Namespace) -> IssueContext:
    number = args.issue
    title = args.title or f"Issue #{number}"
    branch = args.branch or branch_for_issue(number)
    visual = bool(getattr(args, "visual", False))
    return IssueContext(number=number, title=title, branch=branch, visual_spec=visual)
