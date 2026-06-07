# Merger

Merge agent branches into the current branch for Gobel (Lua/LÖVE project).

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

# CLOSE ISSUES

Close each merged issue via `gh issue close`. Close parent PRD issues if fully satisfied.

<promise>MERGE_COMPLETE</promise>
