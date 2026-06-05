# PRD: Stones Implementation Entry — Test Spec & Comment Corrections

**Status:** ready-for-agent  
**Source:** Grill-me session on `STONES_IMPLEMENTATION_ENTRY.md` and `stones_tests_remarks.md`  
**Triage label:** `ready-for-agent`  
**Scope:** Modify **only** the stones implementation entry document (31 stone sections + global conventions). No game code, no spec file implementation, no animation/heuristic rewrites unless folded into Comment-driven `implementation_details` fixes.

---

## Problem Statement

The stones implementation entry document is the normative handoff for stone behavior and verification, but its **tests** sections do not meet the bar for implementation or review. Short bullet lists and a separate **visual tests to be written** section confuse “visual” with UI feedback (floating text, icons) rather than the project’s real pattern: executable scenarios that assert **game state** with board topology described precisely enough to implement later.

`implementation_details` for several stones is wrong or incomplete relative to inline **Comment:** notes from the author. Non-commented stones may have acceptable behavior text, but their test descriptions are still too shallow (e.g. end-of-turn territory stones “tested” in one turn on an empty board, `tax_stone` missing nested-enclosure and multi-round cases).

Agents and developers cannot derive ≥10 distinct, meaningful scenarios per stone from the current entry point, which slows correct resolver/effect work and duplicates effort when someone almost writes a full spec in the markdown.

## Solution

Rewrite the stones implementation entry document as a self-contained **entry point**: merge all test intent into a single **tests** section per stone using narrative **given → when → then** (and chained **when → then** for multi-step flows). Add a global **Tests** conventions block. Remove **visual_tests_to_be_written** everywhere. Update **implementation_details** only for stones that have author **Comment:** corrections; for those stones, narratives follow the corrected behavior in the same pass. Leave **animations_details** and **heuristics_details** unchanged unless a Comment explicitly requires a behavior note there (none today).

## User Stories

### Document consumers

1. As a **Code Writer agent**, I want one **tests** section per stone with clear given/when/then narratives, so that I know what to implement in spec code without re-deriving scenarios from vague bullets.
2. As a **Code Writer agent**, I want global test-writing rules at the top of the entry document, so that every stone section follows the same format without re-reading chat history.
3. As a **reviewer**, I want at least ten unique scenarios per stone documented before the stone is considered spec-complete, so that obvious edge cases (multi-round, capture, nested enclosure) are not missed.
4. As a **reviewer**, I want stone-level checkboxes for “tests specified” and “tests implemented in code”, so that doc progress and code progress are distinguishable without per-scenario checkbox noise.
5. As a **designer/author**, I want **Comment:** feedback merged into **implementation_details** and removed as raw comments, so that the normative text and tests stay aligned.
6. As a **designer/author**, I want non–Comment stones to keep their current **implementation_details** prose, so that scope stays limited to test rewrites where behavior was already agreed.
7. As an **AI planner**, I want test narratives to reference **parameters** for expected values, so that balance changes do not obsolete the doc with hardcoded literals.
8. As an **AI planner**, I want non-empty initial positions described as verbal topology plus `(row,col)` for stones that matter, so that spatial stones are implementable without pasting full 9×9 ASCII into the entry doc.
9. As a **developer**, I want **then** clauses to assert only resolver-visible **game state**, so that the entry doc does not duplicate **animations_details**.
10. As a **developer**, I want white stones referred to as **W** in coordinate/board mentions, so that narratives match existing visual spec letter conventions.

### Global conventions

11. As a **reader**, I want a **Tests** subsection under global conventions defining format, count, uniqueness, and assertion scope, so that I can validate any stone section against one checklist.
12. As a **reader**, I want “N rounds” and “this round” definitions unchanged in globals, so that timing language in new narratives stays consistent with existing gameplay rules.
13. As a **reader**, I want dedupe/trigger-key globals unchanged unless a Comment stone requires documenting new state (e.g. per-cell territory control over rounds), so that cross-stone rules stay in one place.

### Per-stone test content (all 31 stones)

14. As a **Code Writer**, I want **basic_stone** scenarios to cover placement payout and no delayed side effects after turn advance, so that the baseline is nailed before complex stones.
15. As a **Code Writer**, I want **points_stone** / **influence_stone** tier scenarios for all tiers and upgrade-only-affects-next-placement, so that tiered defs are fully specified.
16. As a **Code Writer**, I want **tower_stone** corner vs non-corner territory value cases, so that corner gating is explicit.
17. As a **Code Writer**, I want **energy_stone** scenarios for immediate energy gain and max energy unchanged across opponent turn, so that economy rules are unambiguous.
18. As a **Code Writer**, I want **x_stone** and **plus_stone** scenarios for new-tier completion, no re-score, and multi-pattern completion in one move, so that mult sub-phase behavior is documented at state level.
19. As a **Code Writer**, I want **diagonal_stone** scenarios reflecting **wall-like placement-only** scoring (per Comment), not line-completion tiers, so that implementation matches author intent.
20. As a **Code Writer**, I want **line_stone** scenarios reflecting **wall-like placement-only** scoring (per Comment), so that orthogonal line completion tiers are not wrongly specified.
21. As a **Code Writer**, I want **kamikaze_stone** scenarios for illegal-placement override, self-removal, points, and prisoner side effects if enabled, so that sacrifice flow is complete.
22. As a **Code Writer**, I want **enclosure_stone** scenarios for doubling enclosed field values (per Comment), not single-cell +1 territory_value, so that territory amplifier behavior matches description.
23. As a **Code Writer**, I want **control_stone** scenarios for last-wins territory override during assignment (per Comment), including contested cancel cases, so that resolver ordering is explicit.
24. As a **Code Writer**, I want **blockade_stone** scenarios for adjacent blocks, duration, overlap max-duration, and kamikaze still blocked, so that occupancy rules are testable.
25. As a **Code Writer**, I want **defence_stone** scenarios for +1 **solidity** to connected stones on placement and when new stones connect later (per Comment), so that solidity propagation is specified not abstract “defense value.”
26. As a **Code Writer**, I want **money_field_stone** enclosed vs open placement scenarios, so that conditional economy is covered.
27. As a **Code Writer**, I want **anti_capture_stone** immunity duration, scope at trigger, and expiry scenarios, so that capture blocking is multi-step.
28. As a **Code Writer**, I want **mult_3_rounds_stone** scenarios for **2 × rounds controlled** payout and territory-round tracking sign convention (per Comment), so that stable-territory mult is measurable.
29. As a **Code Writer**, I want **points_3_rounds_stone** scenarios for **7-round** survival timer (per Comment), destroy-before-payout, and single payout, so that delayed points match new duration.
30. As a **Code Writer**, I want **capture_stone** single-target, multi-target deterministic choice, and +3 bonus scenarios, so that combat RNG is bounded in spec.
31. As a **Code Writer**, I want **tax_stone** scenarios for tax inside enclosure, per-enemy payouts, nested enclosure stopping payout, multi-round **end_of_turn**, and no double payout with two tax in one region, so that remarks in stones_tests_remarks are satisfied in prose.
32. As a **Code Writer**, I want **self_destruct_timed_stone** immediate points and timed removal scenarios, so that lifetime is separated from kamikaze.
33. As a **Code Writer**, I want **territory_to_points_stone** scenarios for per-round payout based on **current owner of stone’s territory** and total territory controlled by that player, parameterized divisor, cap, ownership flip, capture, blockade, and multiple territory stones (per Comment and remarks), so that empty-board one-turn tests are eliminated.
34. As a **Code Writer**, I want **territory_to_multiplier_stone** scenarios parallel to territory-to-points but asserting **plus_mult** (per Comment), so that the pair stays symmetric in the doc.
35. As a **Code Writer**, I want **escalating_points_stone** per-round accumulation, parameterized capture multiplier transfer to enemy (per Comment), so that banked value behavior is explicit.
36. As a **Code Writer**, I want **escalating_money_stone** per-round money growth and parameterized capture penalty multiple/triple total paid (per Comment), so that economy punishment differs from points escalator.
37. As a **Code Writer**, I want **wall** group-size threshold scenarios (no bonus below block size, stacked blocks), so that connected-group points match existing implementation text.
38. As a **Code Writer**, I want **unlimited_upgrades_stone** high-level and cost-growth scenarios, so that uncapped upgrades are stressed.
39. As a **Code Writer**, I want **final_blow_stone** final-round vs non-final payout scenarios, so that round-limit gating is documented.
40. As a **Code Writer**, I want **high_power_money_loss_stone** simultaneous gain/loss and money clamp scenarios, so that tradeoff is state-assertable.
41. As a **Code Writer**, I want **copper_stone** below-threshold and at-threshold synergy scenarios, so that board count matters.
42. As a **Code Writer**, I want **retrigger_stone** valid replay, excluded effects, no chain, and fallback +1 scenarios, so that combo tail behavior is complete.

### Comment stones — implementation_details alignment

43. As an **author**, I want **diagonal_stone** **implementation_details** to describe placement-only scoring like **wall**, so that tests and behavior text agree.
44. As an **author**, I want **line_stone** **implementation_details** to describe placement-only scoring like **wall**, so that line-completion tiers are removed from normative text.
45. As an **author**, I want **enclosure_stone** **implementation_details** to describe doubling values of fields in the enclosure, so that description and details match.
46. As an **author**, I want **control_stone** **implementation_details** to specify resolve-last override during territory assignment, so that ordering is normative.
47. As an **author**, I want **defence_stone** **implementation_details** to use **solidity** increases for connected stones including future connections, so that effects layer matches stone parameter model.
48. As an **author**, I want **mult_3_rounds_stone** **implementation_details** to specify **2 × rounds controlled** and game-state territory-round tracking (negative white / positive black), so that mult stones can share one mechanism.
49. As an **author**, I want **points_3_rounds_stone** timer updated to **7 rounds**, so that delayed payout matches author tuning.
50. As an **author**, I want **territory_to_points_stone** **implementation_details** to describe per-round points to the player who owns the stone’s cell’s territory and their total controlled territory, with parameterized divisor, so that end-of-turn conversion is not a one-shot floor formula only.
51. As an **author**, I want **territory_to_multiplier_stone** **implementation_details** to mirror territory-to-points with mult outcomes, so that pair stays consistent.
52. As an **author**, I want **escalating_points_stone** **implementation_details** to describe per-round point generation and capture transfer with parameterized multiplier, so that banked value on capture is normative.
53. As an **author**, I want **escalating_money_stone** **implementation_details** to describe per-round money and capture penalty with parameterized multiple, so that payback on capture is normative.

### Uniqueness and quality bar

54. As a **reviewer**, I want two scenarios to count as different if either **board topology** or **trigger/outcome/chain** differs, so that “ten tests” cannot be ten placements of the same assert.
55. As a **reviewer**, I want scenarios that only move placement cell without changing meaning to be rejected during doc pass, so that padding is caught early.
56. As a **reviewer**, I want expected numeric outcomes expressed via **parameter symbols** where balance matters, so that the doc survives parameter edits.
57. As a **reviewer**, I want multi-step stones (**end_of_turn**, timers, blockade expiry, immunity) to include at least several chained **when/then** narratives, so that timing bugs are spec-visible before code exists.

### Structural cleanup

58. As a **reader**, I want no **visual_tests_to_be_written** headings remaining, so that “visual” is not misread as UI tests.
59. As a **reader**, I want obsolete UI-oriented test lines (e.g. “no special multiplier text”) removed or replaced with state assertions, so that the doc matches project testing philosophy.
60. As a **maintainer**, I want raw **Comment:** lines removed after merge into **implementation_details**, so that the entry doc has a single normative voice per section.

## Implementation Decisions

### Deliverable

- Single markdown artifact: the **stones implementation entry** document (title may remain “Objects Implementation Entry Point” or be renamed to reflect stones-only scope — optional, not required for this PRD).

### Global Conventions — new Tests block

Add a **Tests** subsection that codifies:

| Rule | Decision |
|------|----------|
| Structure | One **tests** section per stone; delete **visual_tests_to_be_written** entirely. |
| Format | Narrative paragraphs using **given**, **when**, **then**; repeat **when/then** for multi-action flows. |
| Empty board | One-line given (e.g. empty 9×9). |
| Non-empty board | Verbal topology + `(row,col)` for each stone that matters for assertions; use **W** for white. |
| Minimum count | ≥10 scenarios per stone (all 31 stones). |
| Uniqueness | Scenario counts if topology **or** behavioral dimension differs (not both required). |
| Assertions | **Then** = game state only (points, mult, money, energy, territory ownership/value, board contents, legality, timers, capture/prisoners). |
| Values | Prefer parameter references over hardcoded balance numbers. |
| Progress flags | Stone-level: `tests specified (≥10 scenarios)` and `tests implemented in code` — same checkbox style as other sections. |
| Authority | **Comment** stones: update **implementation_details** from Comment, then write tests against that; remove Comment lines. **Non-Comment** stones: keep **implementation_details**; rewrite **tests** only. |

### Comment stones — behavior text updates (11 stones)

Merge inline Comments into **implementation_details** (and globals if needed for shared territory-round tracking) for:

- **diagonal_stone**, **line_stone** — placement-only scoring analogous to **wall** (connected-group / placement trigger), not pattern-completion tier tables currently in the doc.
- **enclosure_stone** — doubles field values inside owner-enclosed territory (not merely +1 territory_value on placed cell).
- **control_stone** — territory assignment: resolve last; override previous assignments; contested handling when both players apply control.
- **defence_stone** — **solidity** +1 to orthogonal and diagonal neighbors; on placement and when later stones connect; affects self and connected stones.
- **mult_3_rounds_stone** — payout **2 × number of rounds controlled**; document reading **rounds controlled** from game state (per-cell territory control history: negative = white, positive = black) in globals or stone section.
- **points_3_rounds_stone** — survival timer **7 rounds** (was 3).
- **territory_to_points_stone** — each round: determine owner of territory at stone cell; add parameterized points (e.g. floor(territory/4)) to that player based on their total controlled territory; cap as parameter.
- **territory_to_multiplier_stone** — same structure as territory-to-points with mult outcome.
- **escalating_points_stone** — points each round while on board; on capture, accumulated value goes to enemy with parameterized multiplier (2×/3×).
- **escalating_money_stone** — money each round; on capture, pay parameterized multiple of total received.

### Sections explicitly not in scope for rewrite

- **animations_details** — leave as-is (no grill agreement to change).
- **heuristics_details** — leave as-is.
- **description** one-liners — change only if needed for consistency after Comment merge on the eleven stones.

### Work ordering (recommended execution)

1. Add global **Tests** conventions.
2. Process **Comment** stones (implementation_details + ≥10 tests each).
3. Process remaining stones (tests only, ≥10 each).
4. Pass: remove all **visual_tests_to_be_written** blocks; reset test checkboxes to `[ ] tests specified` until narratives complete; keep `[x] implemented` on other sections where already true.

### Domain vocabulary (use in narratives)

- **playing_stones** macro, sub-phases **territory → points → mult**
- **end_of_turn**, round timing, **solidity**, **territory_value**, enclosure, **plus_mult**, **x_mult**
- **ObjectInstance** / stone **level** / tiers where relevant
- Resolver as authority; narratives describe observable outcomes after placement resolution and turn boundaries

## Testing Decisions

### What this PRD “tests”

This project phase **does not implement** automated tests. “Testing” here means **specification quality** of scenarios in the entry document. A good documented scenario:

- Describes **external behavior** visible in game state after resolver/turn boundaries, not internal effect IDs or UI.
- Uses **given/when/then** (or chains) so another developer can implement a visual or unit spec without guessing setup.
- Varies **topology or outcome** so the ≥10 count produces interesting boards (author’s rationale for hard minimum).
- References **parameters** for expected deltas where balance matters.

### Seams (confirm these match your expectations)

Scenarios in the entry document should be written at the **highest observable seam** already used in the codebase’s visual specs — without mandating where files live in this PRD:

1. **Isolated game state** — setup hand, board, energy, stone instance tier/level, optional seeded territory scores.
2. **Placement resolution** — single **when**: play stone from hand; **then**: immediate scoring/territory/mult deltas and board changes.
3. **Turn boundary** — **when**: finish turn / pass turn / advance rounds; **then**: **end_of_turn** payouts, timer ticks, blockade expiry, immunity expiry.
4. **Territory assignment** — **then**: ownership grids or territory value assertions where enclosure, control override, influence, tower corner matter.
5. **Capture / removal** — **when**: capture or timed removal; **then**: transferred banked value, penalties, reset progression.

No new test harness or doc linter is in scope; validation is human/agent review against the global **Tests** checklist.

### Prior art (informative, not modified in this PRD)

- Existing **visual** stone scoring specs: tier/immediate stones, end-of-turn economy batch, pattern stones — multi-step helpers and ASCII assertions in repo tests.
- **stones_tests_remarks.md** — thematic requirements especially for **tax_stone**, territory conversion stones, parameter literals, **W** for white.

### Module under test (conceptual)

- The **stones implementation entry** document itself, as normative input to future **effects + resolver** work and spec authorship.

## Out of Scope

- Implementing or rewriting **spec/visual**, **spec/unit**, or **test_helper** code.
- Changing **objects/definitions**, **effects**, **resolver**, **parameters**, or **main** UI.
- Updating **animations_details** or **heuristics_details** sections (except incidental wording if author requests later).
- Renaming stone IDs or adding/removing stones beyond the existing 31 sections.
- Publishing gameplay fixes in code to match new text (separate implementation PRs follow this doc).
- Deciding per-scenario file placement (visual vs unit directories).
- Automated CI validation that each stone has ≥10 scenarios.
- Merging **stones_tests_remarks.md** into the entry doc (may be used as reference only).

## Further Notes

- **Volume:** 31 stones × ≥10 narratives ≈ 310 scenarios — plan phased delivery (e.g. Comment stones + high-risk economy/pattern stones first) if a single PR is too large.
- **capture_stone** section in the current doc has extra blank lines — cleanup optional during edit.
- **Issue tracker:** Publish this PRD as a GitHub issue with label `ready-for-agent` when `gh` is available; until then this file is canonical.
- **Seam check:** If you want scenarios documented at a lower seam (e.g. per-effect unit names), say so before implementation; default remains observable game state after placement and turn boundaries.
