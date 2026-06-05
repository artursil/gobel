# PRD: Visual Stones Scoring Specs — Align with Implementation Entry

**Status:** ready-for-agent  
**Source:** Completed `STONES_IMPLEMENTATION_ENTRY.md` rewrite (issue #1); grill-me test conventions; `stones_tests_remarks.md`  
**Triage label:** `ready-for-agent`  
**Scope:** Update executable visual specs under the stones scoring visual suite **except** the manually curated x/plus/wall spec (leave that file unchanged). Add missing visual coverage where the entry document lists stones not yet represented in any scoring visual file.

---

## Problem Statement

The stones implementation entry document now defines **at least ten** narrative **given → when → then** scenarios per stone, with corrected behavior for Comment-driven stones (wall-style diagonal/line placement scoring, enclosure doubling, control override ordering, territory-round tracking, per-round territory conversion, capture-transfer escalators, nested tax enclosures, and more). The existing stones scoring visual specs predate that rewrite: they bundle a handful of `it()` cases per file (~63 examples across seven files), often assert **hardcoded** numeric expectations, use inconsistent white-stone letters (`b` vs `W`), and still encode **obsolete** rules (diagonal/line tier completion, old tax and territory-to-points formulas, old mult-on-aged-cell payout, escalating points only on voluntary sell, and similar).

A Code Writer implementing effects from the entry document cannot treat current visual specs as authoritative verification. Failing or misleading specs will block confident merges and encourage re-duplication of scenarios the entry doc already spelled out. The one curated x/plus/wall visual file is trusted by the author and must not be reworked in this effort.

## Solution

Rebuild the stones scoring visual suite so **every stone except those exclusively covered in the curated x/plus/wall file** has **≥10** distinct, executable examples that trace to the matching numbered scenarios in the implementation entry document. Keep the established visual-spec pattern: isolated game via test helper, letter-encoded ASCII boards, placement and turn-advance helpers, score/territory/money/legality assertions, and `visual_scoring_debug_after_each` for failure diagnosis. Replace hardcoded payout literals with **parameters helper** derivations. Standardize **W** for white stones in board encodings. Do not change game resolver/effect code in this PRD—only specs and, where necessary, **test support** helpers/parameters accessors required to express entry-doc scenarios.

## User Stories

### Traceability and authority

1. As a **Code Writer**, I want each visual `it()` title to map to a numbered scenario in the implementation entry stone section, so that spec drift is visible in review.
2. As a **reviewer**, I want the file header comment to list covered stone IDs and point to the entry document sections, so that scope per file is obvious.
3. As a **author**, I want the curated x/plus/wall visual file left untouched, so that manually tuned pattern/wall cases remain stable.
4. As a **developer**, I want obsolete examples removed rather than commented out, so that failing tests reflect real gaps in implementation not legacy behavior.

### Coverage volume (28 stones in rework scope)

5. As a **Code Writer**, I want **at least ten** `it()` blocks per stone in the rework set, so that the entry document’s minimum is satisfied in executable form.
6. As a **Code Writer**, I want **basic_stone** visual coverage that asserts the stone is inert (no points, mult, or delayed effects) with **five** scenarios only, so the baseline is documented without padding to ten tests.
7. As a **Code Writer**, I want **tier_immediate** file cases expanded for `points_stone`, `influence_stone`, `energy_stone`, and `tower_stone` to ten each, so that tier, energy persistence, and corner territory behaviors are fully exercised.
8. As a **Code Writer**, I want **pattern_lines** rewritten for wall-style `diagonal_stone` and `line_stone` placement bonuses (not length-tier pattern scoring), so that specs match Comment-corrected entry text.
9. As a **Code Writer**, I want **pattern_lines** to retain ten scenarios each for `kamikaze_stone` and `capture_stone` including legality, payout, RNG determinism, and prisoner edge cases.
10. As a **Code Writer**, I want **territory_enclosure** to assert enclosure **value doubling** for `enclosure_stone`, not single-cell `+1 territory_value` markers only.
11. As a **Code Writer**, I want **territory_enclosure** `control_stone` cases to validate resolve-last override semantics and contested cancellation per entry doc.
12. As a **Code Writer**, I want **territory_enclosure** `money_field_stone` and `copper_stone` deciles completed to ten scenarios including threshold and below-threshold board counts.
13. As a **Code Writer**, I want **protection_blockade** `defence_stone` cases to assert **solidity** propagation on placement and on later adjacent placements, not abstract defense denominators alone.
14. As a **Code Writer**, I want **protection_blockade** `mult_3_rounds_stone` to assert `2 × rounds_controlled` using territory-round tracking sign convention (positive black, negative white).
15. As a **Code Writer**, I want **protection_blockade** `blockade_stone` and `anti_capture_stone` multi-round chains (duration, overlap max, kamikaze still blocked, immunity expiry, silent failed capture).
16. As a **Code Writer**, I want **timed_delayed** `points_3_rounds_stone` to use the **seven-round** timer from entry doc (not three), with capture-forfeit and independent timers across stones.
17. As a **Code Writer**, I want **timed_delayed** `self_destruct_timed_stone`, `final_blow_stone`, and `unlimited_upgrades_stone` each at ten scenarios including round-gate and post-cap upgrade payouts.
18. As a **Code Writer**, I want **end_of_turn_economy** `tax_stone` nested-enclosure, multi-round, capture-before-payout, and dual-region cases per entry scenarios 1–10.
19. As a **Code Writer**, I want **end_of_turn_economy** `territory_to_points_stone` and `territory_to_multiplier_stone` to test per-round payout to **current cell territory owner** with total-territory formula, caps, flip to white, contested zero, multiple stones, blockade, and capture—not one-shot `set_player_territory_score` on empty board only.
20. As a **Code Writer**, I want **end_of_turn_economy** `escalating_money_stone` capture penalty multiples and progression reset cases per entry doc.
21. As a **Code Writer**, I want **tradeoff_retrigger** `escalating_points_stone` per-round point accrual and parameterized enemy capture transfer (not sell-to-cash-out only).
22. As a **Code Writer**, I want **tradeoff_retrigger** `high_power_money_loss_stone` and `retrigger_stone` deciles including money clamp, wall replay, no retrigger chain, and fallback point.
23. As a **developer**, I want stones only in the curated file (`x_stone`, `plus_stone`, `wall`) excluded from scenario-count requirements in other files, so that rework scope stays bounded.

### Parameters and letters

24. As a **reviewer**, I want expected points/money/mult caps computed via parameters helper accessors, so that balance tuning does not require spec edits.
25. As a **Code Writer**, I want new parameters helper functions added when entry doc references symbols not yet exposed to specs (tax per enemy, T2P divisor/cap, escalating capture multipliers, diagonal/line block formulas, tier payouts, and similar).
26. As a **developer**, I want white stones drawn as **`W`** in ASCII placement strings, so that visual specs match entry-doc letter convention and author preference.

### Test harness

27. As a **Code Writer**, I want `finish_turn`, `pass_turn`, `advance_rounds`, and opponent `place_stone_for` used consistently for multi-step entry narratives, so that timing scenarios match prior art in existing visual specs.
28. As a **Code Writer**, I want test helper support to seed `territory_control_rounds` (or equivalent) when scenarios require rounds-controlled counts, so that mult-on-control stones are testable without resolver internals assertions.
29. As a **Code Writer**, I want territory ASCII and territory-value ASCII assertions for enclosure/control/influence cases, so that territory-phase outcomes remain player-visible at the highest seam.
30. As a **Code Writer**, I want legality helpers for blocked cells and kamikaze zero-liberty placement, so that rule negatives are state-level, not implementation hooks.

### Completion and CI

31. As a **maintainer**, I want the full visual stones scoring suite (including curated file) to pass under busted once rework lands and implementation catches up, or failures explicitly tagged pending implementation with team agreement—not silently deleted assertions.
32. As a **author**, I want entry document `tests implemented in code` checkboxes updated stone-by-stone as each stone reaches ten passing examples, so that doc and code progress stay linked.
33. As a **reviewer**, I want scenario uniqueness enforced the same way as the entry doc (topology or outcome chain differs), so that padding with trivial coordinate shifts is rejected in PR review.

### File organization

34. As a **developer**, I want describe blocks grouped **by stone ID** inside each existing file, so that navigation mirrors the entry document order.
35. As a **Code Writer**, I want a new visual file for **basic_stone** only if it keeps other files under readable size, so that the seven rework files do not become unreviewable monoliths in one PR.
36. As a **developer**, I want PRs split by file or stone cluster if total line count is large, so that review remains tractable.

## Implementation Decisions

### In-scope artifacts

- Seven existing stones scoring visual spec modules (tier/immediate, pattern/lines, territory/enclosure, protection/blockade, timed/delayed, end-of-turn economy, tradeoff/retrigger).
- **New** stones scoring visual module for **basic_stone** (only stone in the 31-stone catalog missing from non-curated visual coverage).
- **parameters helper** extensions for any entry-doc parameter symbols used in expectations.
- **test helper** extensions only when necessary to seed territory-round grids, solidity reads, stored-value counters, or other **observable** state named in the entry document—no resolver refactors.

### Explicitly excluded

- The curated **x / plus / wall** visual spec module (no edits, no scenario rewrites, no drive-by formatting).
- Other visual integration modules outside the stones scoring cluster (territory integration, wall detection, generic scoring visual, enclosure integration at parent visual directory)—unless a later PR explicitly expands scope.
- Changes to **implementation entry** markdown except flipping `tests implemented in code` checkboxes when specs land.
- **effects**, **resolver**, **definitions**, **parameters** balance values, **animations**, **heuristics**, and **UI**.
- Pixel/UI animation assertions; floating text and icon presence remain out of scope.

### Stone-to-file mapping (rework targets)

| Visual module cluster | Stone IDs (10+ `it()` each) |
|----------------------|----------------------------|
| Tier / immediate | `basic_stone` (new file), `points_stone`, `influence_stone`, `energy_stone`, `tower_stone` |
| Pattern / sacrifice | `diagonal_stone`, `line_stone`, `kamikaze_stone`, `capture_stone` |
| Territory / enclosure | `enclosure_stone`, `control_stone`, `money_field_stone`, `copper_stone` |
| Protection / blockade | `blockade_stone`, `defence_stone`, `anti_capture_stone`, `mult_3_rounds_stone` |
| Timed / delayed | `points_3_rounds_stone`, `self_destruct_timed_stone`, `final_blow_stone`, `unlimited_upgrades_stone` |
| End-of-turn economy | `tax_stone`, `territory_to_points_stone`, `territory_to_multiplier_stone`, `escalating_money_stone` |
| Tradeoff / retrigger | `escalating_points_stone`, `high_power_money_loss_stone`, `retrigger_stone` |

**Out of rework file edits:** `x_stone`, `plus_stone`, `wall` (curated module only).

### Behavioral alignment priorities (specs must track entry doc)

- **diagonal_stone / line_stone:** wall-style connected-group placement payout formulas; delete length-3/5/7 tier completion expectations.
- **enclosure_stone:** double enclosed field values, not isolated `+1` on placed cell only.
- **control_stone:** territory assignment override resolves last; contested when opposing control applies same cell same pass.
- **defence_stone:** `+1 solidity` to orthogonal and diagonal neighbors on placement and when later stones connect.
- **mult_3_rounds_stone:** payout `2 × rounds_controlled` from territory-round tracking grid (positive black, negative white).
- **points_3_rounds_stone:** **7-round** survival timer before delayed points payout.
- **tax_stone:** innermost qualifying enclosure only; no nested double pay; per-enemy parameterized money/points each owner `end_of_turn`.
- **territory_to_points_stone / territory_to_multiplier_stone:** each `end_of_turn`, pay **current territory owner at stone cell** based on that owner’s **total** controlled territory; parameterized divisor and cap; no territory consumption.
- **escalating_points_stone:** accrue points each round; on capture, transfer accumulated value to enemy with parameterized multiplier.
- **escalating_money_stone:** accrue money each round; on capture, enemy receives parameterized multiple of total received.

### Parameters policy

- Every numeric expectation in new/rewritten `it()` blocks must come from **parameters helper** (or a named derived function there), not literal `2`, `15`, `+6`, except for structurally obvious counts (e.g. number of enemy stones in setup = 3 → expected tax payout uses `3 * P.tax_money_per_enemy()`).
- When entry doc introduces a symbol without a helper, add the accessor in the same PR cluster as the spec that needs it.

### Letter maps and setup style

- Extend `LETTER_TO_STONE` / `STONE_TO_LETTER` per file for all stones under test; use **`W`** for white basic and white-specific placements.
- Prefer `set_stone_instance` for tier/level, `set_energy` / `set_hand` where given clauses require them.
- Multi-step narratives use chained helper calls matching entry **when → then** order; one `it()` per numbered scenario where practical.

### Execution / PR strategy

- Recommended order: (1) parameters helper + test helper gaps, (2) **basic_stone** new file, (3) pattern_lines and end_of_turn_economy (largest behavioral deltas), (4) remaining clusters.
- Curated x/plus/wall module remains the reference for style quality; reworked files should match its assertion clarity and debug hooks without copying its cases.
- Update implementation entry `tests implemented in code` from `[ ]` to `[x]` per stone as that stone’s ten examples exist and pass (or are skipped with explicit pending marker only if team agrees—default is pass-required).

## Testing Decisions

### What makes a good visual stones scoring test

- Assert **external game state** after placement resolution or turn boundaries—points deltas, money, energy, mult, territory owner grids, territory value grids, board occupancy, legality, timers, capture/prisoners—not effect registry internals, RNG seeds in isolation, or UI text.
- **One scenario per entry numbered test** where feasible; title references stone id and scenario intent (e.g. `tax_stone scenario 5: nested enclosure no double pay`).
- **Given** encoded as `set_board` ASCII plus helpers; **when** as `place_stone` / `finish_turn` / `advance_rounds` / opponent moves; **then** as existing `assert_player_*` and territory ASCII helpers.
- Scenarios must differ by **topology or outcome chain** (same rule as entry doc); reject duplicate placement-only moves.

### Seams (highest first — confirm these match expectations)

1. **Isolated match state** — `new_isolated_game`, hand/energy/instance seeding, optional territory score seeding only when entry scenario allows testable shortcut without faking owner-at-cell rules incorrectly.
2. **Single placement resolution** — `place_stone` letter diff on board; assert immediate playing_stones outcomes.
3. **Turn boundary** — `finish_turn` / `pass_turn` / `advance_rounds` for `end_of_turn`, timers, blockade decay, immunity expiry, escalating payouts.
4. **Territory assignment visibility** — `assert_territory_ascii` / `assert_territory_values_ascii` after placement or turn advance when enclosure, control, influence, tower corner matter.
5. **Opponent interaction** — `place_stone_for`, capture helpers, ownership flip before `end_of_turn` for territory conversion and tax.
6. **Legality negative seam** — `assert_legal_player_move_with_stone` / illegal variants for blockade and kamikaze override positives.

No new seam below isolated game state unless test helper must expose an observable field already defined in entry globals (e.g. territory-round grid).

### Modules under test

- Stones scoring **visual spec modules** (rework set + new basic module).
- Supporting **parameters helper** and **test helper** surfaces used by those specs.

### Prior art

- Curated x/plus/wall visual module (read-only reference for structure and assertion style).
- Existing rework-target modules before edit (multi-step time option C comments, `visual_scoring_debug_after_each`, `assert_stone_ids_registered_in_content`).
- Implementation entry document § Global Conventions Tests table and per-stone numbered lists 1–10.
- Prior PRD for entry document rewrite (issue #1).

## Out of Scope

- Editing the curated x/plus/wall visual module.
- Parent-directory visual integration specs (non–stones-scoring cluster).
- Implementing or fixing resolver/effects to make new specs pass (follow-up implementation PRs; specs may land first and fail until code catches up only if explicitly coordinated—default is implement specs alongside or after effect work in same delivery milestone).
- **Unit** specs under `spec/unit` (may be added later; not required by this PRD).
- Animation/heuristic verification.
- Rewriting implementation entry narratives.
- CI job creation for “≥10 per stone” counting.
- AI/heuristic bot tests.

## Further Notes

- **Scale:** ~28 stones × ≥10 examples ≈ **280+** `it()` blocks in rework scope vs ~63 today—expect multi-PR delivery.
- **Implementation lag:** Many entry stones remain `[ ] not implemented` in `implementation_details`; specs should still encode correct expected behavior and fail until code matches, unless the team chooses `@pending` tags—document the chosen policy in the implementation PR.
- **Issue tracker:** Publish as GitHub issue with `ready-for-agent` label; canonical copy in repo `mds/` PRD file until linked.
