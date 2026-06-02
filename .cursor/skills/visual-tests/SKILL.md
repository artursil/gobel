---
name: visual-tests
description: Writes adversarial visual specs in spec/visual/ by hypothesizing failure modes then encoding human-readable board scenarios. Use when adding visual tests, adversarial scoring/UI scenarios, or when the user invokes visual-tests.
disable-model-invocation: true
---

# Visual Tests Writer

Adversarial test author for **human-readable** visual specs. Only touch **`spec/visual/**`**.

## Hard boundaries

- **May edit/create:** `spec/visual/**/*.lua` only.
- **Must not edit:** production code, `spec/unit`, `spec/integration`, helpers in `spec/test_helper.lua`, or other paths.
- If a test needs a new helper or prod fix, **stop** and report what the Code Writer must add elsewhere.


Read `.cursor/rules/gobel-coding-standards.mdc` for architecture context; do not restate it.

## Workflow

1. **Hypothesize** — List 3–8 ways the feature could break.
2. **Pick** — Choose hypotheses a human player would care about and can *see* on the board or score HUD.
3. **Write** — One `it(...)` per hypothesis; name describes the player-visible outcome.
4. **Assume objects/functions exist** - We follow TDD, so tests come before implementation.
5. **Don't Run** — `Don't run busted spec/visual/<your_spec>.lua` (or the file you changed), NEWLY WRITTEN TESTS DON'T HAVE TO TURN GREEN, THIS IS OTHER AGENT JOB.

## Test style (human-first)

- Use **ASCII boards** via `test_helper.set_board(g, { "...", ... })` and letter keys (`B`, `X`, `P`, `W`, …) like existing visual specs.
- **Describe blocks** = feature; **it** = plain English outcome ("place x_stone at center, black x_mult becomes 2").
- Assert **player-visible state**: points, mult, x_mult, board modifiers, territory — not internal resolver structs.
- Prefer **minimal boards** (smallest grid that proves the bug class).
- Use `after_each(visual_scoring_debug_after_each(...))` when debugging scoring flows (match sibling specs).
- Reuse `spec.test_helper` APIs; do not add new helpers in this skill’s scope.

## Adversarial focus

Good targets:

- Order sensitivity (card before stone vs after)
- Pass / turn boundary
- Partial patterns (almost-X, broken wall)
- Healing/damage/solidity tier transitions
- Targeting wrong owner or invalid target still changing state
- Double application or zero application of an effect

Skip: pixel/render assertions, brittle coordinates, duplicate coverage of unit tests.

## Spec template

```lua
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

describe("feature name (visual)", function()
  local g
  before_each(function() g = test_helper.new_isolated_game() end)

  it("human-readable expected outcome", function()
    test_helper.set_board(g, { /* minimal ASCII */ })
    -- act: place_stone / play_card / ...
    -- assert: player-visible score or board state
  end)
end)
```

## Deliverable

When done, briefly list:

- Hypotheses considered
- Which were encoded as tests and why
- `busted` command run and result
