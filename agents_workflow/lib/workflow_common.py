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
from lib.workflow_logger import WorkflowRunLogger

MAX_ITERATIONS = 4
VISUAL_TEST_FIXER_PROMPT = "visual-test-fixer"


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


def run_code_writer(
    ctx: IssueContext,
    *,
    cwd: Path,
    extra: str = "",
    logger: WorkflowRunLogger | None = None,
    log_phase: str = "initial/code-writer",
) -> str:
    variables = issue_variables(ctx)
    extra_context = extra or "(none)"
    variables["EXTRA_CONTEXT"] = extra_context
    prompt = load_prompt("code-writer", variables)
    text = run_agent("Code Writer", prompt, cwd=cwd).text
    if logger is not None:
        logger.log_agent("code-writer", text, phase=log_phase, extra_context=extra_context)
    return text


def run_test_writer(
    ctx: IssueContext,
    *,
    cwd: Path,
    extra: str = "",
    logger: WorkflowRunLogger | None = None,
    log_phase: str = "initial/test-writer",
) -> str:
    variables = issue_variables(ctx)
    extra_context = extra or "(none)"
    variables["EXTRA_CONTEXT"] = extra_context
    prompt = load_prompt("test-writer", variables)
    text = run_agent("Test Writer", prompt, cwd=cwd).text
    if logger is not None:
        logger.log_agent("test-writer", text, phase=log_phase, extra_context=extra_context)
    return text


def run_visual_test_writer(
    ctx: IssueContext,
    *,
    cwd: Path,
    extra: str = "",
    prompt_name: str = "visual-test-writer",
    logger: WorkflowRunLogger | None = None,
    log_phase: str = "initial/visual-test-writer",
) -> str:
    variables = issue_variables(ctx)
    extra_context = extra or "(none)"
    variables["EXTRA_CONTEXT"] = extra_context
    prompt = load_prompt(prompt_name, variables)
    agent_label = "Visual Test Fixer" if prompt_name == "visual-test-fixer" else "Visual Test Writer"
    text = run_agent(agent_label, prompt, cwd=cwd).text
    if logger is not None:
        logger.log_agent(
            "visual-test-writer",
            text,
            phase=log_phase,
            extra_context=extra_context,
        )
    return text


def run_delegator(
    ctx: IssueContext,
    *,
    cwd: Path,
    code_writer_output: str,
    test_writer_output: str = "",
    iteration: int,
    logger: WorkflowRunLogger | None = None,
) -> DelegationResult:
    variables = issue_variables(ctx)
    variables["ITERATION"] = str(iteration)
    variables["CODE_WRITER_OUTPUT"] = code_writer_output
    variables["TEST_WRITER_OUTPUT"] = test_writer_output or "(no test-writer output this iteration)"
    prompt = load_prompt("delegator", variables)
    text = run_agent("Delegator", prompt, cwd=cwd).text
    result = parse_delegation(text)
    if logger is not None:
        logger.log_delegation(text, result, iteration=iteration)
    return result


def run_assigned_agents(
    delegation: DelegationResult,
    ctx: IssueContext,
    *,
    cwd: Path,
    logger: WorkflowRunLogger | None = None,
    iteration: int,
    visual_test_prompt: str = "visual-test-writer",
) -> dict[str, str]:
    outputs: dict[str, str] = {}
    for assignment in delegation.assignments:
        extra = f"{assignment.reason}\n\n{assignment.task}"
        phase = f"iteration-{iteration:02d}/assigned/{assignment.agent}"
        if assignment.agent == "code-writer":
            outputs["code-writer"] = run_code_writer(
                ctx, cwd=cwd, extra=extra, logger=logger, log_phase=phase
            )
        elif assignment.agent == "test-writer":
            outputs["test-writer"] = run_test_writer(
                ctx, cwd=cwd, extra=extra, logger=logger, log_phase=phase
            )
        elif assignment.agent == "visual-test-writer":
            outputs["visual-test-writer"] = run_visual_test_writer(
                ctx,
                cwd=cwd,
                extra=extra,
                prompt_name=visual_test_prompt,
                logger=logger,
                log_phase=phase,
            )
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


def tests_exist_loop(
    ctx: IssueContext,
    *,
    cwd: Path,
    visual_test_prompt: str = VISUAL_TEST_FIXER_PROMPT,
) -> bool:
    """Tests already on branch: code-writer → delegator → assigned fixes (loop)."""
    logger = WorkflowRunLogger.start(
        "tests_exist",
        issue_number=ctx.number,
        branch=ctx.branch,
        title=ctx.title,
    )
    code_output = run_code_writer(
        ctx,
        cwd=cwd,
        logger=logger,
        log_phase="initial/code-writer",
    )
    test_output = ""
    last_delegation: DelegationResult | None = None

    for iteration in range(1, MAX_ITERATIONS + 1):
        print(f"\n=== tests_exist iteration {iteration}/{MAX_ITERATIONS} (#{ctx.number}) ===")

        concerns = parse_test_concerns(code_output)
        if concerns:
            print("[code-writer] raised test concerns")
            logger.log_test_concerns(concerns, iteration=iteration)

        last_delegation = run_delegator(
            ctx,
            cwd=cwd,
            code_writer_output=code_output,
            test_writer_output=test_output,
            iteration=iteration,
            logger=logger,
        )

        if last_delegation.status == "complete":
            print(f"[delegator] complete for #{ctx.number}")
            logger.finalize(success=True)
            return True

        fix_outputs = run_assigned_agents(
            last_delegation,
            ctx,
            cwd=cwd,
            logger=logger,
            iteration=iteration,
            visual_test_prompt=visual_test_prompt,
        )
        if "code-writer" in fix_outputs:
            code_output = fix_outputs["code-writer"]
        if "test-writer" in fix_outputs:
            test_output = fix_outputs["test-writer"]
        if "visual-test-writer" in fix_outputs:
            test_output = fix_outputs["visual-test-writer"]

    escalate(ctx, last_delegation or DelegationResult(status="needs_work"), iterations=MAX_ITERATIONS)
    logger.finalize(success=False, escalated=True)
    return False


def single_feature_loop(ctx: IssueContext, *, cwd: Path) -> bool:
    """Tests first → code-writer → delegator → assigned fixes (loop)."""
    logger = WorkflowRunLogger.start(
        "single_feature",
        issue_number=ctx.number,
        branch=ctx.branch,
        title=ctx.title,
    )
    if ctx.visual_spec:
        test_output = run_visual_test_writer(
            ctx,
            cwd=cwd,
            logger=logger,
            log_phase="initial/visual-test-writer",
        )
    else:
        test_output = run_test_writer(
            ctx,
            cwd=cwd,
            logger=logger,
            log_phase="initial/test-writer",
        )

    code_output = run_code_writer(
        ctx,
        cwd=cwd,
        extra=test_output,
        logger=logger,
        log_phase="initial/code-writer",
    )
    last_delegation: DelegationResult | None = None

    for iteration in range(1, MAX_ITERATIONS + 1):
        print(f"\n=== single_feature iteration {iteration}/{MAX_ITERATIONS} (#{ctx.number}) ===")

        concerns = parse_test_concerns(code_output)
        if concerns:
            print("[code-writer] raised test concerns")
            logger.log_test_concerns(concerns, iteration=iteration)

        last_delegation = run_delegator(
            ctx,
            cwd=cwd,
            code_writer_output=code_output,
            test_writer_output=test_output,
            iteration=iteration,
            logger=logger,
        )

        if last_delegation.status == "complete":
            print(f"[delegator] complete for #{ctx.number}")
            logger.finalize(success=True)
            return True

        fix_outputs = run_assigned_agents(
            last_delegation,
            ctx,
            cwd=cwd,
            logger=logger,
            iteration=iteration,
        )
        if "code-writer" in fix_outputs:
            code_output = fix_outputs["code-writer"]
        if "test-writer" in fix_outputs:
            test_output = fix_outputs["test-writer"]
        if "visual-test-writer" in fix_outputs:
            test_output = fix_outputs["visual-test-writer"]

    escalate(ctx, last_delegation or DelegationResult(status="needs_work"), iterations=MAX_ITERATIONS)
    logger.finalize(success=False, escalated=True)
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
