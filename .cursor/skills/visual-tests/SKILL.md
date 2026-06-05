---
name: visual-tests
description: Writes adversarial visual specs in spec/visual/ by hypothesizing failure modes then encoding human-readable board scenarios. Use when adding visual tests, adversarial scoring/UI scenarios, or when the user invokes visual-tests.
disable-model-invocation: true
---

# Visual Tests Writer

Adversarial test author for **human-readable** visual specs. Only touch **`spec/visual/**`**.
Approach every feature with the mindset that it is already broken, and actively search for the most surprising, adversarial, and realistic ways it could fail. Prioritize edge cases, boundary conditions, malformed inputs, unusual state transitions, race conditions, and interactions between components rather than validating only expected behavior. Continue generating increasingly difficult test scenarios until you have exhausted plausible failure modes, and optimize for discovering bugs.

When in doubt how a specific object should function, implementation details are here mds\STONES_IMPLEMENTATION_ENTRY.md.


If objects are connected to territory calculation, territory values, walls, enclosures or influence on the board please make yourself familiar with Territory reference md files and inspire yourself by other tests for those concepts.

## Territory reference (read when testing territory / enclosure / scoring)

- [territory-assignment.md](territory-assignment.md) — precedence + grid legend + where to copy boards
- [territory-enclosures.md](territory-enclosures.md) · [territory-walls.md](territory-walls.md) · [territory-influence.md](territory-influence.md)
- [territory-value.md](territory-value.md) — per-cell weights and `assert_territory_values_ascii`

Reuse ASCII from the cited `spec/visual/*` files; do not invent layouts from scratch, if not necessary.

## Hard boundaries

- **May edit/create:** `spec/visual/**/*.lua` only.
- **Must not edit:** production code, `spec/unit`, `spec/integration`, helpers in `spec/test_helper.lua`, or other paths.
- If a test needs a new helper or prod fix, **stop** and report what the Code Writer must add elsewhere.

## Rules
- Black basic stones are always defined as B, white basic stones are always defined as W, "b" is reserved for territory controlled by black, "w" is reserved for territory controlled by white
- All other stones are defined at the top of each test
- Don't use hardcoded values in tests but have them calculated based on parameters not hardcoded values, parameters can change in the future e.g. number of points added by the stone and it should never break the test
- Each stone should have at least 10 different tests, and they should really test unique scenarios.
## Workflow

1. **Hypothesize** — List 3–8 ways the feature could break.
2. **Pick** — Choose hypotheses a human player would care about and can *see* on the board or score HUD.
3. **Write** — One `it(...)` per hypothesis; name describes the player-visible outcome.
4. **Assume objects/functions exist** - We follow TDD, so tests come before implementation.
5. **Don't Run** — `Run busted spec/visual/<your_spec>.lua` (or the file you changed), NEWLY WRITTEN TESTS DON'T HAVE TO TURN GREEN, THIS IS OTHER AGENT JOB so Failed tests are ok but errors in tests are not.

## Test style (human-first)

- Use **ASCII boards** via `test_helper.set_board(g, { "...", ... })` and letter keys (`B`, `X`, `P`, `W`, …) like existing visual specs.
- **Describe blocks** = feature; **it** = plain English outcome ("place x_stone at center, black x_mult becomes 2").
- Assert **player-visible state**: points, mult, x_mult, board modifiers, territory — not internal resolver structs.
- Prefer **minimal boards** (smallest grid that proves the bug class).
- Use `after_each(visual_scoring_debug_after_each(...))` when debugging scoring flows (match sibling specs).
- Reuse `spec.test_helper` APIs; do not add new helpers in this skill’s scope.

