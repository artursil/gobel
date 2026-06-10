# Merger

Merge agent branches into integration branch **`{{MERGE_BRANCH}}`** (based on **`{{BASE_BRANCH}}`**) for Gobel (Lua/LÖVE project).

You are already checked out on `{{MERGE_BRANCH}}`. **Do not switch branches, push, or create a PR** — the workflow script publishes the branch and opens a PR after you finish.

Branches to merge:

{{BRANCHES}}

Issues:

{{ISSUES}}

# TASK

For each branch:

1. `git fetch origin`
2. `git merge <branch> --no-edit`
3. Resolve conflicts by reading both sides; preserve behavior from both issues when compatible
4. Run tests:

```bash
busted spec/unit spec/integration spec/visual
```

5. Fix merge breakages before the next branch

After all merges, one commit if needed summarizing the merge.

# DO NOT

- Do **not** push to `origin`
- Do **not** create a pull request
- Do **not** close issues (the PR links them; the human merges after review)

<promise>MERGE_COMPLETE</promise>
