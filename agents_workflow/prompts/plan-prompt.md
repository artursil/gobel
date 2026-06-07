# Planner

Analyze open GitHub issues and pick parallelizable work for Gobel agent workflows.

# ISSUES

<issues-json>

!`gh issue list --state open --label ready-for-agent --limit 100 --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`

</issues-json>

# TASK

Build a dependency graph. Issue B is **blocked by** A when:

- B needs code or infrastructure A introduces
- B and A modify overlapping modules likely to conflict
- B depends on an API shape A establishes

An issue is **unblocked** when it has no blockers among open issues.

Assign branch names: **`agent/issue-{number}`** (deterministic, no slug).

PRD-only issues with linked implementation children are **not** workable themselves.

Prefer issues labeled:

- `tests-exist` → `tests_exist` workflow (tests on branch; implement only)
- `visual-spec` or `needs-visual-spec` → visual test path
- default → unit/integration test path for `single_feature`

# OUTPUT

<plan>
{"issues": [{"number": 42, "title": "Capture bonus", "branch": "agent/issue-42", "workflow": "tests_exist"}]}
</plan>

`workflow` is one of: `tests_exist`, `single_feature`. Include only unblocked issues (or the single best candidate if all blocked).

<promise>PLAN_COMPLETE</promise>
