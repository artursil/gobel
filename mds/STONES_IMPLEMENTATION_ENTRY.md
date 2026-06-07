# Stones Implementation Entry Point

This document is the normative implementation handoff for stones.
Visual specs assert resolver-visible game state only.

## Global Conventions

- Board size: `9x9`.
- Resolve macro for stone placement effects: `playing_stones`.
- Sub-phase order: `territory -> points -> mult`.
- Unless stated otherwise, a stone effect triggers only for the player who placed that stone.
- "This round" means until `end_of_turn` cleanup.
- "N rounds" means current round counts as round 1.
- If two rules could trigger at once, run lower `priority` first, then higher `priority`.
- If the same effect instance is already applied for the same trigger key (stone id + row + col + round + owner), do not apply it again.
- Territory control rounds: dense `9×9` grid `territory_control_rounds[row][col]` — positive for Black streak length, negative for White (`W`), `0` for contested/no man's land or stone-occupied cells. Maintenance rules and test ASCII format: `docs/territory/control-rounds.md`.
- Capture scoring: on stone placement, award `capture_bonus_points_per_stone` × enemy stones removed; independent of stone type. Details: `docs/capture/scoring.md`.

### Tests

| Rule | Decision |
|------|----------|
| Structure | One `tests` section per stone; no separate visual test section. |
| Format | Narrative scenarios using **given -> when -> then**; chain additional **when -> then** for multi-round flows. |
| Empty board | One-line given is allowed. |
| Non-empty board | Describe topology verbally and include `(row,col)` for relevant stones; use `W` for white stones. |
| Minimum count | At least 10 scenarios per stone; `basic_stone` is exempt (inert stone, fewer scenarios). |
| Uniqueness | A scenario is unique when topology or outcome chain differs. |
| Assertions | Then clauses only assert game state: points, mult, money, energy, territory owner/value, board contents, legality, timers, captures/prisoners. |
| Values | Use parameter names where balancing may change. |
| Progress flags | Keep two checkboxes: `tests specified (>=10 scenarios)` and `tests implemented in code`. |

---

## 1. basic_stone

**name:** `basic_stone` (`stone_basic` in content)
**description:** Inert placement token. It has no stone-specific scoring, multiplier, territory, economy, or delayed effects.

### implementation_details
- [x] implemented
- On placement, apply no stone effect: `STONE_BASIC_PLACEMENT_POINTS = 0`, no `playing_stones` payout from this stone id.
- No multiplier, territory, timer, economy, or `end_of_turn` effect registered for this stone.
- Core Go rules (capture, ko, legality) still apply; they are not stone effects.

### animations_details
- [x] implemented
- Standard placement animation only; no bonus float text from this stone.

### heuristics_details
- [x] implemented
- Baseline move evaluation only; no stone-specific heuristic term.

### tests
- [x] tests specified (5 scenarios; inert stone exempt from 10-scenario minimum)
- [ ] tests implemented in code

---

## 2. scoring_points_stone_tiered

**name:** `points_stone`
**description:** Direct points stone with three upgrade tiers.

### implementation_details
- [ ] not implemented
- Tier payouts are parameters: `POINTS_STONE_T1`, `POINTS_STONE_T2`, `POINTS_STONE_T3`.
- Trigger on placement only.
- Upgrading affects future placements of upgraded instances only.

### animations_details
- [ ] not implemented
- Show tier-based points float text.

### heuristics_details
- [ ] not implemented
- Prefer higher tier instances.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 3. influence_stone_tiered

**name:** `influence_stone`
**description:** Territory-distance modifier with three tiers.

### implementation_details
- [ ] not implemented
- Tier distance bonuses are parameters: `INFLUENCE_T1`, `INFLUENCE_T2`, `INFLUENCE_T3`.
- Applies in `playing_stones.territory` with `territory_step=distance`.
- Stacks additively with other distance effects.

### animations_details
- [ ] not implemented
- Territory pulse around influence source.

### heuristics_details
- [ ] not implemented
- Prefer contested areas.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 4. tower_stone

**name:** `tower_stone`
**description:** Corner-only territory value amplifier.

### implementation_details
- [x] implemented (core)
- On placement add base points.
- If placed in corner, increase territory value in the corner `3x3` block except the tower cell.
- Non-corner placements do not apply corner value effect.

### animations_details
- [ ] not implemented
- Corner area highlight when active.

### heuristics_details
- [x] implemented (basic)
- Prefer legal corners.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 5. energy_stone

**name:** `energy_stone`
**description:** Economy stone for immediate energy gain with no max-energy change.

### implementation_details
- [ ] not implemented
- On placement, increase current energy by `ENERGY_STONE_GAIN`.
- Does not modify `max_energy`.
- No delayed/recurring payout from this stone.

### animations_details
- [ ] not implemented
- Energy gain feedback.

### heuristics_details
- [ ] not implemented
- Prefer when current energy is low.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 6. x_stone

**name:** `x_stone`
**description:** Pattern multiplier stone for X completions.

### implementation_details
- [x] implemented
- X tiers are `5, 9, 13, 17, 21`.
- Trigger only when placement creates or upgrades an X tier.
- Multiply `x_mult` by `X_STONE_MULT_FACTOR` once per `x_stone` in each newly completed X.
- Same center+tier+owner cannot score twice.

### animations_details
- [x] implemented
- Bounce X cells; show multiplier label per `x_stone`.

### heuristics_details
- [x] implemented
- Near-complete and blocking heuristics exist.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 7. plus_stone

**name:** `plus_stone`
**description:** Pattern plus-mult stone for plus completions.

### implementation_details
- [x] implemented
- Plus tiers are `5, 9, 13, 17, 21`.
- Trigger only when placement creates or upgrades a plus tier.
- Add `PLUS_STONE_BONUS_PER_CELL` per `plus_stone` in each newly completed plus.
- Same center+tier+owner cannot score twice.

### animations_details
- [x] implemented
- Bounce plus cells; show plus-mult label per `plus_stone`.

### heuristics_details
- [x] implemented
- Near-complete and blocking heuristics exist.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: should work more like wall_stone, because there is not much to be completed in terms of diagonal line, so we get points only on placement of diagonal stone

## 8. diagonal_stone

**name:** `diagonal_stone`
**description:** Placement-scoring stone that behaves like wall-style placement reward, not diagonal completion reward.

### implementation_details
- [ ] not implemented
- Trigger only when `diagonal_stone` is placed.
- Compute orthogonally connected group size including placed stone.
- Points bonus formula mirrors wall-style block scoring using diagonal parameters: `floor(group_size / DIAGONAL_STONE_BLOCK_SIZE) * DIAGONAL_STONE_POINTS_PER_BLOCK`.
- No pattern-completion line tier logic.
- Same placement key cannot score twice.

### animations_details
- [ ] not implemented
- Placement reward feedback.

### heuristics_details
- [ ] not implemented
- Prefer placements joining larger own groups.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: should work the same way wall stone does, so we get points only placement in line_stone, we need to be precise here in the implementation details.

## 9. line_stone

**name:** `line_stone`
**description:** Placement-scoring stone that behaves like wall-style placement reward, not line-completion tier reward.

### implementation_details
- [ ] not implemented
- Trigger only when `line_stone` is placed.
- Compute orthogonally connected group size including placed line stone.
- Points bonus formula: `floor(group_size / LINE_STONE_BLOCK_SIZE) * LINE_STONE_POINTS_PER_BLOCK`.
- No horizontal/vertical completion tier table for this stone.
- Same placement key cannot score twice.

### animations_details
- [ ] not implemented
- Placement reward feedback.

### heuristics_details
- [ ] not implemented
- Prefer merges that cross block thresholds.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 10. kamikaze_stone

**name:** `kamikaze_stone`
**description:** Sacrifice stone with illegal-placement override and immediate self-removal payout.

### implementation_details
- [ ] not implemented
- Placement legality override applies to self-atari/no-liberty placements for this stone.
- On placement resolve, stone is removed from board.
- Add `KAMIKAZE_POINTS_BONUS` points once.
- Prisoner side-effect uses configured rule `KAMIKAZE_SELF_REMOVAL_COUNTS_AS_PRISONER`.

### animations_details
- [ ] not implemented
- Placement and self-removal feedback.

### heuristics_details
- [ ] not implemented
- Prefer positive immediate swing.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: implementation details don't really match this description "if placed inside enclosed territory doubles the value of a fields in the enclosure"

## 11. enclosure_stone

**name:** `enclosure_stone`
**description:** Territory amplifier that doubles field values inside owner enclosure.

### implementation_details
- [ ] not implemented
- Trigger condition: placed cell is in owner-enclosed territory.
- Effect: all fields inside that enclosure region have territory value multiplied by `ENCLOSURE_STONE_MULTIPLIER`.
- Multiplication applies to region fields, not only placed cell.
- Non-enclosed placement yields no special effect.
- If multiple enclosure multipliers affect same field, apply multiplicatively in effect order.

### animations_details
- [ ] not implemented
- Enclosure region emphasis when active.

### heuristics_details
- [ ] not implemented
- Prefer enclosed high-value regions.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: Implementation details I don't like, during the territory resolution simply this should be resolved last and override previous assignments.

## 12. control_stone

**name:** `control_stone`
**description:** Territory assignment override stone resolved last.

### implementation_details
- [ ] not implemented
- Control assignment runs after normal territory ownership assignment.
- For affected cells, latest control override wins over previous assignment.
- If both players apply control to same cell in same resolve, cell becomes contested.
- Scope is configured set around stone (currently orthogonal adjacent empties unless definition changes).

### animations_details
- [ ] not implemented
- Control zone feedback.

### heuristics_details
- [ ] not implemented
- Prefer contested conversion opportunities.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 13. blockade_stone

**name:** `blockade_stone`
**description:** Temporarily blocks placement on nearby cells just for an opponent.

### implementation_details
- [ ] not implemented
- Affected cells: orthogonally adjacent cells.
- Block duration parameter: `BLOCKADE_DURATION_ROUNDS`.
- Block applies to all stone types, including `kamikaze_stone`.
- Overlapping blockades keep max remaining duration per cell.

### animations_details
- [ ] not implemented
- Blocked-cell indicator.

### heuristics_details
- [ ] not implemented
- Prefer denying high-value opponent candidates.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: stones have solidity parameter so defense stone should increase solidity by 1 to all diagonally and orthogonally connected stones on placement, but also when next other stones are placed next to it they should get increase solidity by 1, so this stone should have effects for itself and all stones.

## 14. defence_stone

**name:** `defence_stone`
**description:** Solidity amplifier for connected stones, including future connections.

### implementation_details
- [ ] not implemented
- On placement, apply `+1 solidity` to defence stone and all orthogonally/diagonally connected own stones in its effect scope.
- When new own stones later become connected to defence network, they receive `+1 solidity` automatically while connection holds.
- Solidity bonus is a stone parameter modification, not a separate chance formula.
- Multiple defence sources stack additively by source count.

### animations_details
- [ ] not implemented
- Solidity/defence feedback marker.

### heuristics_details
- [ ] not implemented
- Prefer protecting high-value clusters.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 15. money_field_stone

**name:** `money_field_stone`
**description:** Immediate money payout stone gated by enclosed placement.

### implementation_details
- [ ] not implemented
- If placed in owner-enclosed territory, add `MONEY_FIELD_PAYOUT`.
- Otherwise add zero.
- One-time placement payout only.

### animations_details
- [ ] not implemented
- Money feedback.

### heuristics_details
- [ ] not implemented
- Prefer enclosed placements.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---


Comment: This stone prevents opponent to place a stone on an empty field that would capture this stone if active. After ANTI_CAPTURE_DURATION_ROUNDS it becomes a regular stone.

## 16. anti_capture_stone

**name:** `anti_capture_stone`
**description:** Temporary capture immunity stone.

### implementation_details
- [ ] not implemented
- Immunity duration parameter: `ANTI_CAPTURE_DURATION_ROUNDS`.
- Applies to snapshot scope at trigger time: placed stone + connected own stones.
- New stones connected later are not included unless re-triggered.
- After expiry, stones revert to normal capture rules.

### animations_details
- [ ] not implemented
- Immunity state feedback.

### heuristics_details
- [ ] not implemented
- Prefer threatened groups.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: I would change it to 2 * number of rounds controlled. For this and other stones in implementation we also need to specify how to get information about number of rounds in controlled territory. I would suggest in state of the game store information about territory controlled over rounds where negative numbers are for white player and positive are for black player.

## 17. control_territory_stone

**name:** `control_territory_stone`
**description:** Multiplier stone based on territory control streak length at placement.

### implementation_details
- [x] implemented
- Grid maintenance: see `docs/territory/control-rounds.md`.
- Read `territory_control_rounds[row][col]` at placement time (before cell is occupied), sign convention positive black / negative `W`.
- Own territory: add `mult_control_streak_multiplier * abs(streak)` to placer `plus_mult`.
- Enemy territory: subtract `mult_control_streak_multiplier * abs(streak)` from placer `plus_mult`; floor `plus_mult` at `0`.
- Neutral (`0`): no payout.
- Trigger is one-time on placement.

### animations_details
- [ ] not implemented
- Stable-control reward feedback.

### heuristics_details
- [ ] not implemented
- Prefer high absolute owner-control streak cells; avoid enemy-controlled cells (penalty).

### tests
- [x] tests specified (>=8 scenarios; payout formula only — grid tick tests in `spec/unit/territory_control_rounds_spec.lua`)
- [x] tests implemented in code
- Seed control grid via `set_territory_control_rounds_ascii`; minimal stone boards; enclosure topology out of scope.
- Assert `expected_delta = mult_control_streak_multiplier * N` (or negative equivalent) from parameters helper.

---

Comment: This is ok but I would increase it to 7 rounds

## 18. delay_reward_stone

**name:** `delay_reward_stone`
**description:** Delayed points stone with a 7-round survival timer.

### implementation_details
- [ ] not implemented
- On placement, register survival timer `POINTS_DELAY_ROUNDS = 7`.
- If stone still exists when timer expires, grant `POINTS_DELAY_PAYOUT`.
- If removed/captured before expiry, no payout.
- Payout triggers once per stone instance.

### animations_details
- [ ] not implemented
- Countdown feedback.

### heuristics_details
- [ ] not implemented
- Prefer safe longevity placements.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 19. capture_stone

**name:** `capture_stone`
**description:** Placement-triggered capture stone that removes one enemy stone with zero liberties, regardless of which color surrounds it.

### implementation_details
- [ ] not implemented
- Trigger on placement only.
- Eligible targets: enemy stones with exactly **0 liberties** after this stone is placed. Unlike basic Go capture, it does not matter which colors surround the target — only that the target has no empty orthogonal neighbors.
- If exactly one eligible target exists, capture (remove) it.
- If multiple eligible targets exist, select one at random via RNG stream key `capture_stone`.
- After a stone is captured, the opponent cannot immediately place a stone on the now-empty capture cell; the cell is blocked for the opponent for **1 round** (capture cooldown). The capturing player may place on that cell freely.
- If no eligible target exists (no enemy stone at 0 liberties), no capture occurs.

### animations_details
- [ ] not implemented
- Target-capture feedback.

### heuristics_details
- [ ] not implemented
- Prefer high-value captures.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 20. tax_stone

**name:** `tax_stone`
**description:** End-of-turn tax payout from enemy stones inside qualifying enclosure.

### implementation_details
- [ ] not implemented
- Trigger at each owner `end_of_turn`.
- For each qualifying enclosure region containing at least one owner tax stone, count enemy stones in that region.
- Payout per counted enemy stone is parameterized: `TAX_MONEY_PER_ENEMY` and `TAX_POINTS_PER_ENEMY`.
- Two or more tax stones in the same region do not multiply payout.
- Nested enclosure rule: only active innermost owner enclosure that contains the tax stone pays; outer nested region does not double-pay same enemy stones.

### animations_details
- [ ] not implemented
- Region payout feedback.

### heuristics_details
- [ ] not implemented
- Prefer dense enemy-enclosure regions.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 21. self_destruct_timed_stone

**name:** `self_destruct_timed_stone`
**description:** Immediate points stone that auto-removes after a timer.

### implementation_details
- [ ] not implemented
- On placement add `SELF_DESTRUCT_IMMEDIATE_POINTS`.
- Register removal timer `SELF_DESTRUCT_DELAY_ROUNDS`.
- On expiry, remove stone from board.
- No payout on removal.

### animations_details
- [ ] not implemented
- Timer and removal feedback.

### heuristics_details
- [ ] not implemented
- Prefer immediate swing opportunities.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: This needs to be totally differently implemented. Conversion formula I guess is ok as long 4 is a parameter, but we should add this number of points each rund but depending to whom the territory where the stone was placed belongs this time. So firstly we check to whom belongs the territory where this stone is placed. Then we check entire territory controlled by this player and we add this number of points to their points score.

## 22. territory_to_points_stone

**name:** `territory_to_points_stone`
**description:** End-of-turn points generator based on current owner of the stone cell and that owner's total controlled territory.

### implementation_details
- [ ] not implemented
- Trigger each `end_of_turn` while stone remains on board.
- Determine owner of territory at the stone cell at trigger time.
- Let that owner be `T_OWNER`; compute payout from `T_OWNER` total controlled territory using parameterized formula: `min(T2P_CAP, floor(T_OWNER_TERRITORY / T2P_DIVISOR))`.
- Add payout to `T_OWNER` points (not necessarily stone owner if cell territory flips).
- No territory consumption/reduction.

### animations_details
- [ ] not implemented
- Territory-to-points feedback.

### heuristics_details
- [ ] not implemented
- Prefer stable territory ownership around the stone cell.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: should act exactly like the previous stone just with mult

## 23. territory_to_multiplier_stone

**name:** `territory_to_multiplier_stone`
**description:** End-of-turn multiplier generator mirroring territory_to_points behavior.

### implementation_details
- [ ] not implemented
- Trigger each `end_of_turn` while stone remains on board.
- Determine territory owner at stone cell at trigger time.
- Let recipient be that current owner; add `min(T2M_CAP, floor(RECIPIENT_TERRITORY / T2M_DIVISOR))` to `plus_mult`.
- No territory consumption/reduction.
- Behavior is structurally parallel to `territory_to_points_stone` but outputs `plus_mult`.

### animations_details
- [ ] not implemented
- Territory-to-mult feedback.

### heuristics_details
- [ ] not implemented
- Prefer stable high-territory states.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: this stone should give some number of points every round, but then when captured double or triple (should be a parameter as everything) the number of accumulated points goes to the enemy.

## 24. escalating_points_stone

**name:** `escalating_points_stone`
**description:** Per-round point generator with capture transfer multiplier.

### implementation_details
- [ ] not implemented
- While on board, each owner `end_of_turn` adds `EPS_ROUND_POINTS` to this stone's accumulated bank.
- Also add `EPS_ROUND_POINTS` to owner points each round (generator behavior).
- On capture, opponent gains `EPS_CAPTURE_MULTIPLIER * accumulated_bank`.
- On capture/removal, bank resets to zero.
- `EPS_CAPTURE_MULTIPLIER` is parameterized (e.g. 2x or 3x).

### animations_details
- [ ] not implemented
- Accumulation and capture-transfer feedback.

### heuristics_details
- [ ] not implemented
- Prefer safe growth positions.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

Comment: similar to the last stone it should generate more money each round, but if it is captured we has to pay double of triple the money we got before.

## 25. escalating_money_stone

**name:** `escalating_money_stone`
**description:** Per-round money generator with capture penalty multiplier.

### implementation_details
- [ ] not implemented
- While on board, each owner `end_of_turn` adds `EMS_ROUND_MONEY` to owner money and tracks cumulative received total `EMS_TOTAL_RECEIVED`.
- On capture, captured owner pays penalty `EMS_CAPTURE_MULTIPLIER * EMS_TOTAL_RECEIVED`.
- Penalty is applied to captured owner's money with clamp at global min if defined.
- `EMS_CAPTURE_MULTIPLIER` is parameterized (e.g. 2x or 3x).

### animations_details
- [ ] not implemented
- Money growth and penalty feedback.

### heuristics_details
- [ ] not implemented
- Prefer early safe placements.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 26. wall

**name:** `wall`
**description:** Connected-group placement points stone.

### implementation_details
- [x] implemented
- On wall placement, compute orthogonally connected group size including placed wall.
- Bonus formula: `floor(group_size / WALL_STONES_PER_BLOCK) * WALL_POINTS_PER_BLOCK`.
- Trigger only for placed wall coordinate.
- Same placement key cannot score twice.

### animations_details
- [x] implemented
- Group bounce and per-block marker feedback.

### heuristics_details
- [x] implemented (none required)
- Wall value evaluated through direct scoring.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 27. unlimited_upgrades_stone

**name:** `unlimited_upgrades_stone`
**description:** Upgrade-scaling stone with no level cap.

### implementation_details
- [ ] not implemented
- No maximum level.
- Per-upgrade effect increments are parameterized.
- Upgrade cost growth is parameterized by level.

### animations_details
- [ ] not implemented
- High-level upgrade feedback.

### heuristics_details
- [ ] not implemented
- Prefer in long economy-positive games.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 28. final_blow_stone

**name:** `final_blow_stone`
**description:** Last-round payout stone.

### implementation_details
- [ ] not implemented
- If placed on final round, grant configured final payout (`FINAL_BLOW_POINTS`, `FINAL_BLOW_PLUS_MULT`).
- If not final round, grant fallback payout `FINAL_BLOW_NONFINAL_POINTS`.
- Final round comes from current game mode round limit state.

### animations_details
- [ ] not implemented
- Distinct final-round trigger feedback.

### heuristics_details
- [ ] not implemented
- High priority on final round only.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 29. high_power_money_loss_stone

**name:** `high_power_money_loss_stone`
**description:** Immediate high reward with immediate money penalty.

### implementation_details
- [ ] not implemented
- On placement add `HPML_POINTS_GAIN` and `HPML_PLUS_MULT_GAIN`.
- On same resolution subtract `HPML_MONEY_LOSS`.
- If money underflows, clamp by global money floor.

### animations_details
- [ ] not implemented
- Combined gain/loss feedback.

### heuristics_details
- [ ] not implemented
- Penalize low-money states.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 30. copper_stone

**name:** `copper_stone`
**description:** Low baseline stone with synergy threshold behavior.

### implementation_details
- [ ] not implemented
- Base placement payout is `COPPER_BASE_POINTS` (default may be zero).
- Copper tag is available for external synergies.
- Built-in threshold rule: if owner copper count on board is `>= COPPER_THRESHOLD`, add `COPPER_THRESHOLD_PLUS_MULT_BONUS` on new copper placement.

### animations_details
- [ ] not implemented
- Minimal base feedback; stronger threshold feedback.

### heuristics_details
- [ ] not implemented
- Prefer when near threshold.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code

---

## 31. retrigger_stone

**name:** `retrigger_stone`
**description:** Replays most recent valid stone effect from same owner this turn.

### implementation_details
- [ ] not implemented
- On placement, target owner's most recent resolved stone effect in current turn.
- Exclusions: cannot retrigger retrigger itself and effects marked non-retriggerable.
- Replay occurs exactly once.
- If no valid target exists, fallback adds `RETRIGGER_FALLBACK_POINTS`.
- No retrigger chaining: replayed effect cannot open another retrigger from same event.

### animations_details
- [ ] not implemented
- Retrigger indicator then one replay feedback.

### heuristics_details
- [ ] not implemented
- Prefer after high-impact effect has just resolved.

### tests
- [x] tests specified (>=10 scenarios)
- [ ] tests implemented in code
