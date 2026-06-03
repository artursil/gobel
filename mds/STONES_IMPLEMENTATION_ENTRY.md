# Objects Implementation Entry Point

This document defines exact stone behavior for implementation.
All values below are normative and should be treated as source of truth.

## Global Conventions

- Board size: `9x9`.
- Resolve macro for stone placement effects: `playing_stones`.
- Sub-phase order: `territory -> points -> mult`.
- Unless stated otherwise, a stone effect triggers only for the player who placed that stone.
- "This round" means until `end_of_turn` cleanup.
- "N rounds" means current round counts as round 1.
- If two rules could trigger at once, run lower `priority` first, then higher `priority`.
- If the same effect instance is already applied for the same trigger key (stone id + row + col + round + owner), do not apply it again.

---

## 1. basic_stone

**name:** `basic_stone`
**description:** Baseline stone with simple direct scoring. It has no conditional behavior.

### implementation_details
- [x] implemented
- On placement, add exactly `+1 points`.
- No multiplier, territory, or delayed effect.
- Trigger phase: `playing_stones.points`.

### animations_details
- [x] implemented
- Use standard placement animation only.
- No bonus text beyond default score feedback.

### heuristics_details
- [x] implemented
- Use baseline move evaluation only.
- No stone-specific heuristic term.

### tests
- [x] implemented
- Verify placement gives exactly `+1 points`.
- Verify no extra effect in later phases.

### visual_tests_to_be_written
- `basic_stone visual: placement gives exactly +1 points`
- `basic_stone visual: no special multiplier text appears`

---

## 2. scoring_points_stone_tiered

**name:** `points_stone`
**description:** Direct points stone with 3 upgrade tiers. Higher tier gives higher immediate points.

### implementation_details
- [ ] not implemented
- Tier values: `tier1=+2`, `tier2=+4`, `tier3=+7` points.
- Trigger: on placement only, `playing_stones.points`.
- No delayed payout.
- Upgrading changes future placements only, not already placed instances.

### animations_details
- [ ] not implemented
- Show floating text `+2` / `+4` / `+7` based on tier.
- Tier 3 uses stronger color/spark than tier 1.

### heuristics_details
- [ ] not implemented
- Pre-selection bonus by tier: `+1 / +2 / +3`.
- Selection score bonus equals expected immediate point gain divided by 2.

### tests
- [ ] not implemented
- Tier value unit tests for all three tiers.
- Upgrade path test: tier changes next placement payout.

### visual_tests_to_be_written
- `points_stone visual: tier1 shows +2`
- `points_stone visual: tier2 shows +4`
- `points_stone visual: tier3 shows +7`

---

## 3. influence_stone_tiered

**name:** `influence_stone`
**description:** Territory-control stone with 3 tiers. It increases effective territory distance from its cell.

### implementation_details
- [ ] not implemented
- Tier distance bonus: `tier1=+1`, `tier2=+2`, `tier3=+3`.
- Applies in `playing_stones.territory` at `territory_step=distance`.
- Bonus stacks additively with other distance bonuses.
- Affects only owner territory calculations.

### animations_details
- [ ] not implemented
- Show radial pulse from placed stone with radius equal to tier bonus.

### heuristics_details
- [ ] not implemented
- Prefer contested cells where distance swing is positive.
- Pre-selection weight scales with tier: `1.0, 1.5, 2.0`.

### tests
- [ ] not implemented
- Verify per-tier distance bonus.
- Verify additive stacking with lieutenant/tower-like effects.

### visual_tests_to_be_written
- `influence_stone visual: tier1 territory radius pulse`
- `influence_stone visual: tier3 gives larger influence zone`

---

## 4. tower_stone

**name:** `tower_stone`
**description:** Corner-only territory amplifier. It increases territory cell value in the corner `3x3` block around itself.

### implementation_details
- [x] implemented (core)
- On placement, add `+1 points`.
- If placed in any corner, add `+1 territory_value` to each cell in that corner `3x3`, excluding tower cell.
- If not in corner, no territory bonus is applied.
- Trigger phase: `playing_stones.points` and `playing_stones.territory(value)`.

### animations_details
- [ ] not implemented
- Corner activation pulse on the affected `3x3` area.

### heuristics_details
- [x] implemented (basic)
- Prefer legal corner placements.
- No special bonus if no corner move exists.

### tests
- [x] implemented (core)
- Corner placement applies territory value increase.
- Non-corner placement does not apply territory value increase.

### visual_tests_to_be_written
- `tower_stone visual: corner 3x3 area highlights`
- `tower_stone visual: center placement has no corner aura`

---

## 5. energy_stone

**name:** `energy_stone`
**description:** Economy stone that gives immediate energy once when played. It does not increase max energy.

### implementation_details
- [ ] not implemented
- On placement, gain exactly `+2 current energy`.
- Energy is immediate and permanent for this game (not temporary).
- This stone does not change `max_energy`.
- Trigger phase: `playing_stones.points`-adjacent economy step (or dedicated `resource` step if introduced).

### animations_details
- [ ] not implemented
- Floating text `+2 Energy`.
- Brief glow on energy UI value.

### heuristics_details
- [ ] not implemented
- Add pre-selection bonus when `current_energy <= 2`.
- No bonus when `current_energy >= 6`.

### tests
- [ ] not implemented
- Verify `+2 current energy` applied once.
- Verify max energy unchanged.

### visual_tests_to_be_written
- `energy_stone visual: +2 Energy appears on placement`
- `energy_stone visual: current energy increases, max energy unchanged`

---

## 6. x_stone

**name:** `x_stone`
**description:** Multiplier pattern stone for X shapes. It rewards newly completed X tiers by doubling `x_mult` per `x_stone` in each new X.

### implementation_details
- [x] implemented
- X tiers are stone counts `5, 9, 13, 17, 21`.
- Trigger only when move creates a new X tier (not when already complete).
- For each newly completed X, count `x_stone` cells in that X.
- Apply `x_mult *= 2` once per counted `x_stone`.
- Same center+tier+owner cannot score twice.
- Trigger phase: `playing_stones.mult`.

### animations_details
- [x] implemented
- Bounce each stone in completed X in sequence.
- Show `x2` text over each `x_stone` in that X.

### heuristics_details
- [x] implemented
- `x_stone_near_complete`: if own X is within 2 moves, add score.
- `x_stone_block_opponent_x`: if move blocks opponent X within 2 moves, add score.
- Default weights currently `0` unless configured.

### tests
- [x] implemented
- Unit tests for completion, multi-X triggers, and non-completion.
- Unit tests for animation payload correctness.
- Visual tests for small and large X cases.

### visual_tests_to_be_written
- `x_stone visual: one move completes two Xs and both trigger`
- `x_stone visual: no new tier means no x_mult change`

---

## 7. plus_stone

**name:** `plus_stone`
**description:** Multiplier pattern stone for plus shapes. It rewards newly completed plus tiers with flat `+5 plus_mult` per `plus_stone` in the new plus.

### implementation_details
- [x] implemented
- Plus tiers are stone counts `5, 9, 13, 17, 21`.
- Trigger only when move creates a new plus tier.
- For each newly completed plus, count `plus_stone` cells in that plus.
- Add `+5 plus_mult` per counted `plus_stone`.
- Same center+tier+owner cannot score twice.
- Trigger phase: `playing_stones.mult`.

### animations_details
- [x] implemented
- Bounce each stone in completed plus in sequence.
- Show `+5` over each `plus_stone` in that plus.

### heuristics_details
- [x] implemented
- `plus_stone_near_complete`: own plus within 2 moves.
- `plus_stone_block_opponent_plus`: block opponent plus within 2 moves.
- Default weights currently `0` unless configured.

### tests
- [x] implemented
- Unit tests for completion, multi-plus triggers, and non-completion.
- Unit tests for animation payload correctness.
- Visual tests for small and large plus cases.

### visual_tests_to_be_written
- `plus_stone visual: one move completes two pluses and both trigger`
- `plus_stone visual: no new tier means no plus_mult change`

---

## 8. diagonal_stone

Comment: should work more like wall_stone, because there is not much to be completed in terms of diagonal line, so we get points only on placement of diagonal stone

**name:** `diagonal_stone`
**description:** Pattern stone for straight diagonals (not X). It rewards newly completed diagonal lines.

### implementation_details
- [ ] not implemented
- A diagonal line is 3 or more same-owner stones in one straight diagonal direction.
- Directions: `NW-SE` and `NE-SW`.
- Reward on completion/extension this move:
  - length `3-4`: `+2 points`
  - length `5-6`: `+5 points`
  - length `7+`: `+1 x_mult step` (`x_mult *= 1.5`, rounded to 2 decimals only for display, internal full precision)
- Score each unique line endpoint pair once per move.

### animations_details
- [ ] not implemented
- Sweep highlight along completed diagonal.
- Show reward text at midpoint.

### heuristics_details
- [ ] not implemented
- Add score when move reduces own diagonal completion distance.
- Add score when move blocks opponent near-complete diagonal.

### tests
- [ ] not implemented
- Line detection tests for both diagonal directions.
- Multi-line single placement test.

### visual_tests_to_be_written
- `diagonal_stone visual: length3 diagonal gives +2 points`
- `diagonal_stone visual: length5 diagonal gives +5 points`
- `diagonal_stone visual: length7 diagonal applies x_mult step`

---

## 9. line_stone

Comment: should work the same way wall stone does, so we get points only placement in line_stone, we need to be precise here in the implementation details.

**name:** `line_stone`
**description:** Pattern stone for orthogonal straight lines. It rewards newly completed horizontal and vertical lines.

### implementation_details
- [ ] not implemented
- A line is 3 or more same-owner stones in one row or column.
- Reward on completion/extension this move:
  - length `3-4`: `+2 points`
  - length `5-6`: `+4 plus_mult`
  - length `7+`: `+8 plus_mult`
- Same line (same endpoints) cannot score twice in one move.

### animations_details
- [ ] not implemented
- Sweep highlight across line from one end to the other.

### heuristics_details
- [ ] not implemented
- Prefer own near-complete line completion.
- Prefer blocks against opponent line completion.

### tests
- [ ] not implemented
- Horizontal/vertical detection tests.
- Endpoint dedupe tests.

### visual_tests_to_be_written
- `line_stone visual: horizontal length3 trigger`
- `line_stone visual: vertical length5 trigger`

---

## 10. kamikaze_stone

**name:** `kamikaze_stone`
**description:** Sacrifice stone that can be played into normally illegal no-liberty spots and then self-destructs for points.

### implementation_details
- [ ] not implemented
- Override placement legality for this stone only: allow self-atari with zero liberties.
- After placement resolution, remove the stone immediately.
- Grant exactly `+15 points`.
- Count removed stone as own prisoner loss (`+1` to opponent prisoners) only if prisoner tracking is enabled for self-destruction.
- Trigger once on placement.

### animations_details
- [ ] not implemented
- Impact flash, then explode/fade out.
- Show `+15` text at placement cell.

### heuristics_details
- [ ] not implemented
- Prefer when immediate score swing is positive.
- Penalize if move opens large opponent territory.

### tests
- [ ] not implemented
- Legal override tests for zero-liberty positions.
- Self-destruction and score payout tests.

### visual_tests_to_be_written
- `kamikaze_stone visual: zero-liberty placement allowed`
- `kamikaze_stone visual: stone disappears and +15 appears`

---

## 11. enclosure_stone

Comment: implementation details don't really match this description "if placed inside enclosed territory doubles the value of a fields in the enclosure"

**name:** `enclosure_stone`
**description:** Territory amplifier that only works inside already enclosed territory.

### implementation_details
- [ ] not implemented
- Condition: placed cell must be in owner-enclosed territory at resolve time.
- If true, add `+1 territory_value` to that exact cell permanently for current game.
- If false, no special effect.
- Trigger: `playing_stones.territory(value)`.

### animations_details
- [ ] not implemented
- Cell pulse with enclosure icon when condition true.

### heuristics_details
- [ ] not implemented
- Bonus if target cell currently owned and enclosed.
- Zero bonus outside enclosed area.

### tests
- [ ] not implemented
- Inside-enclosure positive case.
- Outside-enclosure negative case.

### visual_tests_to_be_written
- `enclosure_stone visual: enclosed cell gets value marker`
- `enclosure_stone visual: open cell has no marker`

---

## 12. control_stone

Comment: Implementation details I don't like, during the territory resolution simply this should be resolved last and override previous assignments.

**name:** `control_stone`
**description:** Forces liberties next to this stone to count as owner-controlled for territory assignment.

### implementation_details
- [ ] not implemented
- Affected cells: 4 orthogonal adjacent empty cells.
- During territory assignment, mark affected cells with owner override weight `+100`.
- If both players apply control on same cell in same resolve, overrides cancel and cell is contested.
- Effect lasts while stone remains on board.

### animations_details
- [ ] not implemented
- Show 4-cell control ring overlay around stone.

### heuristics_details
- [ ] not implemented
- Prefer contested cells where override flips ownership.

### tests
- [ ] not implemented
- Single-owner override test.
- Double-control cancel test.

### visual_tests_to_be_written
- `control_stone visual: adjacent cells show owner tint`
- `control_stone visual: opposing control marks contested state`

---

## 13. blockade_stone

**name:** `blockade_stone`
**description:** Temporarily blocks placement on nearby cells for both players.

### implementation_details
- [ ] not implemented
- Affected cells: 4 orthogonal adjacent cells.
- Block duration: `4 full rounds` (owner and opponent turns).
- Block applies to all stone types even `kamikaze_stone`.
- If two blockade effects overlap, duration is max remaining duration per cell.

### animations_details
- [ ] not implemented
- Show lock icon on blocked cells.

### heuristics_details
- [ ] not implemented
- Prefer when blocking high-value opponent candidates.

### tests
- [ ] not implemented
- Legal move rejection on blocked cells.
- Expiry after 2 rounds.

### visual_tests_to_be_written
- `blockade_stone visual: adjacent cells show lock`
- `blockade_stone visual: lock disappears after duration`

---

## 14. defence_stone

Comment: stones have solidity parameter so defense stone should increase solidity by 1 to all diagonally and orthogonally connected stones on placement, but also when next other stones are placed next to it they should get increase solidity by 1, so this stone should have effects for itself and all stones.

**name:** `defence_stone`
**description:** Raises defense value and reduces chance-based destroy effects on connected group.

### implementation_details
- [ ] not implemented
- Defense value granted: `+2` to self and orthogonally connected own group.
- For chance effects, effective denominator = `base_denominator * (1 + defense)`.
- Example: `1/4` with defense `2` becomes `1/12`.
- Defense applies while stone remains connected.

### animations_details
- [ ] not implemented
- Shield icon on protected stones.

### heuristics_details
- [ ] not implemented
- Prefer placement that protects high-value stones.

### tests
- [ ] not implemented
- Probability scaling tests.
- Connected group propagation tests.

### visual_tests_to_be_written
- `defence_stone visual: shield appears on connected group`
- `defence_stone visual: destroy effect chance reduced`

---

## 15. money_field_stone

**name:** `money_field_stone`
**description:** Economy stone that pays money when played inside enclosed territory.

### implementation_details
- [ ] not implemented
- Condition: placed cell is owner-enclosed territory.
- On successful condition, gain `+3 money` immediately.
- If condition false, gain `0`.
- No per-round recurring payout.

### animations_details
- [ ] not implemented
- Show coin pop and `+3` at placement.

### heuristics_details
- [ ] not implemented
- Prefer enclosed cells with low tactical downside.

### tests
- [ ] not implemented
- Enclosed condition true/false tests.

### visual_tests_to_be_written
- `money_field_stone visual: enclosed placement gives +3 money`
- `money_field_stone visual: open placement gives no money`

---

## 16. anti_capture_stone

**name:** `anti_capture_stone`
**description:** Grants temporary capture immunity to connected group.

### implementation_details
- [ ] not implemented
- Immunity duration: `2 rounds`.
- Scope: placed stone + orthogonally connected own stones at trigger time.
- New stones connected later are not auto-included.
- Captures against immune stones fail silently.

### animations_details
- [ ] not implemented
- Becomes a normal stone when the immunity is over.

### heuristics_details
- [ ] not implemented
- Prefer when own key group is at low liberties.

### tests
- [ ] not implemented
- Capture blocked during immunity.
- Capture works again after expiry.

### visual_tests_to_be_written
- `anti_capture_stone visual: immune stones show aura`
- `anti_capture_stone visual: aura expires after 2 rounds`

---

## 17. mult_3_rounds_stone

Comment: I would change it to 2 * number of rounds controlled. For this and other stones in implementation we also need to specify how to get information about number of rounds in controlled territory. I would suggest in state of the game store information about territory controlled over rounds where negative numbers are for white player and positive are for black player.

**name:** `mult_3_rounds_stone`
**description:** Rewards stable territory ownership with multiplier.

### implementation_details
- [ ] not implemented
- Condition: placed cell has been owner-controlled for at least `2 previous rounds`.
- If condition true, gain `+6 plus_mult` immediately.
- If false, gain `0`.
- Trigger once on placement.

### animations_details
- [ ] not implemented
- Show `+6` with "stable" tag.

### heuristics_details
- [ ] not implemented
- Prefer older territory cells.

### tests
- [ ] not implemented
- Territory age threshold tests.

### visual_tests_to_be_written
- `mult_3_rounds_stone visual: aged territory triggers +6`
- `mult_3_rounds_stone visual: fresh territory no trigger`

---

## 18. points_3_rounds_stone

Comment: This is ok but I would increase it to 7 rounds

**name:** `points_3_rounds_stone`
**description:** Delayed points stone that pays after surviving 3 rounds.

### implementation_details
- [ ] not implemented
- On placement, register timer `3 rounds`.
- On expiry while stone still exists, gain `+20 points`.
- If destroyed before expiry, reward is lost.
- Reward can trigger only once.

### animations_details
- [ ] not implemented
- Countdown badge `3 -> 2 -> 1`.
- On expiry, burst + points.

### heuristics_details
- [ ] not implemented
- Prefer safe placements with high survival chance.

### tests
- [ ] not implemented
- Countdown progression tests.
- Destroy-before-expiry test.

### visual_tests_to_be_written
- `points_3_rounds_stone visual: countdown ticks each round`
- `points_3_rounds_stone visual: +20 triggers on round 3`

---

## 19. capture_stone



**name:** `capture_stone`
**description:** Executes one opportunistic capture among vulnerable enemies.

### implementation_details
- [ ] not implemented
- Eligible targets: enemy stones with liberties `<=1` after placement.
- If one target: capture it.
- If multiple targets: choose exactly one using deterministic RNG stream `capture_stone`.
- Capture grants `+3 points` bonus in addition to normal capture effects.

### animations_details
- [ ] not implemented
- Target highlight then removal animation.

### heuristics_details
- [ ] not implemented
- Prioritize highest-value capture targets.

### tests
- [ ] not implemented
- Single/multi-target deterministic selection tests.

### visual_tests_to_be_written
- `capture_stone visual: one eligible target captured`
- `capture_stone visual: deterministic choice among multiple targets`

---

## 20. tax_stone

**name:** `tax_stone`
**description:** Converts enclosed enemy presence into economy and score.

### implementation_details
- [ ] not implemented
- Trigger at `end_of_turn`.
- Count enemy stones inside owner-enclosed territory regions that include at least one `tax_stone`.
- Payout per counted enemy stone: `+1 money` and `+1 points`.
- Multiple tax stones in same region do not multiply payout.

### animations_details
- [ ] not implemented
- Region outline + tick payout text.

### heuristics_details
- [ ] not implemented
- Prefer dense enemy-enclosed regions.

### tests
- [ ] not implemented
- Per-stone payout correctness.
- No double payout with multiple tax stones in same region.

### visual_tests_to_be_written
- `tax_stone visual: enclosed enemies generate per-turn payout`
- `tax_stone visual: two tax stones same region no double payout`

---

## 21. self_destruct_timed_stone

**name:** `self_destruct_timed_stone`
**description:** Gives immediate value, then self-destructs after a fixed timer.

### implementation_details
- [ ] not implemented
- On placement: gain `+8 points`.
- Lifetime timer: `2 rounds`.
- On timer expiry: remove stone from board.
- No extra reward on destruction.

### animations_details
- [ ] not implemented
- Countdown indicator + destruction fade.

### heuristics_details
- [ ] not implemented
- Favor when immediate points are needed.

### tests
- [ ] not implemented
- Immediate reward + timed removal tests.

### visual_tests_to_be_written
- `self_destruct_timed_stone visual: +8 then disappears after 2 rounds`

---

## 22. territory_to_points_stone

Comment: This needs to be totally differently implemented. Conversion formula I guess is ok as long 4 is a parameter, but we should add this number of points each rund but depending to whom the territory where the stone was placed belongs this time. So firstly we check to whom belongs the territory where this stone is placed. Then we check entire territory controlled by this player and we add this number of points to their points score.

**name:** `territory_to_points_stone`
**description:** Converts a portion of current territory score into points.

### implementation_details
- [ ] not implemented
- Trigger: `end_of_turn` for owner.
- Conversion formula: add `floor(territory / 4)` points.
- Territory value itself is not reduced (convert-like bonus, not transfer).
- Max per turn cap: `+12 points`.

### animations_details
- [ ] not implemented
- Territory cells pulse, then points text appears.

### heuristics_details
- [ ] not implemented
- Increase value with higher territory totals.

### tests
- [ ] not implemented
- Formula and cap tests.

### visual_tests_to_be_written
- `territory_to_points_stone visual: floor(territory/4) payout`
- `territory_to_points_stone visual: payout cap applies`

---

## 23. territory_to_multiplier_stone

Comment: should act exactly like the previous stone just with mult

**name:** `territory_to_multiplier_stone`
**description:** Converts territory strength into plus multiplier.

### implementation_details
- [ ] not implemented
- Trigger: `end_of_turn`.
- Formula: add `+floor(territory / 6)` to `plus_mult`.
- Max per turn cap: `+8 plus_mult`.
- Does not consume territory.

### animations_details
- [ ] not implemented
- Territory-to-mult beam effect + `+mult` text.

### heuristics_details
- [ ] not implemented
- Prefer when territory baseline is already high.

### tests
- [ ] not implemented
- Formula and cap tests.

### visual_tests_to_be_written
- `territory_to_multiplier_stone visual: plus_mult payout follows formula`

---

## 24. escalating_points_stone

Comment: this stone should give some number of points every round, but then when captured double or triple (should be a parameter as everything) the number of accumulated points goes to the enemy.

**name:** `escalating_points_stone`
**description:** Accumulates points value each round and transfers value to opponent if captured.

### implementation_details
- [ ] not implemented
- On placement, stored value starts at `0`.
- Each `end_of_turn`, stored value increases by `+3`.
- Owner gains stored value as points only when voluntarily selling/removing this stone.
- If captured by opponent, opponent gains stored value instead.
- Stored value resets on removal.

### animations_details
- [ ] not implemented
- Value counter floating over stone.

### heuristics_details
- [ ] not implemented
- Favor safe zones with low capture risk.

### tests
- [ ] not implemented
- Growth, transfer-on-capture, reset tests.

### visual_tests_to_be_written
- `escalating_points_stone visual: value counter increases each turn`
- `escalating_points_stone visual: capture transfers stored value`

---

## 25. escalating_money_stone

Comment: similar to the last stone it should generate more money each round, but if it is captured we has to pay double of triple the money we got before.

**name:** `escalating_money_stone`
**description:** Generates increasing money each round while on board.

### implementation_details
- [ ] not implemented
- Base payout at first `end_of_turn`: `+1 money`.
- Each next turn increases payout by `+1` (`1,2,3,...`).
- Remove stone resets progression.
- Max payout cap per turn: `+6 money`.

### animations_details
- [ ] not implemented
- Coin counter increment effect.

### heuristics_details
- [ ] not implemented
- Favor early placement and safe positions.

### tests
- [ ] not implemented
- Progressive payout and cap tests.

### visual_tests_to_be_written
- `escalating_money_stone visual: payout increases each turn up to cap`

---

## 26. wall

**name:** `wall`
**description:** Connected-group points stone. It rewards large orthogonally connected groups when a wall is placed.

### implementation_details
- [x] implemented
- On wall placement, find orthogonally connected group size including placed wall.
- Bonus formula: `floor(group_size / 5) * 5 points`.
- Trigger only for wall placement cell.
- Same wall placement cannot score twice.

### animations_details
- [x] implemented
- Bounce connected group.
- Show one `+5` marker per full 5-stone block.

### heuristics_details
- [x] implemented (none required)
- No dedicated wall term; handled by direct score evaluation.

### tests
- [x] implemented
- Group thresholds, mixed group composition, and animation marker count.

### visual_tests_to_be_written
- `wall visual: group size 4 no bonus`
- `wall visual: group size 5 +5`
- `wall visual: group size 10 +10`

---

## 27. unlimited_upgrades_stone

**name:** `unlimited_upgrades_stone`
**description:** Upgrade-scaling stone without normal level cap.

### implementation_details
- [ ] not implemented
- No maximum upgrade level.
- Per upgrade gain: `+1 points` and `+1 plus_mult` to this stone's placement effect.
- Cost growth per upgrade: `base_cost + level`.

### animations_details
- [ ] not implemented
- Stronger level-up FX when level exceeds normal cap.

### heuristics_details
- [ ] not implemented
- Favor in long games with surplus economy.

### tests
- [ ] not implemented
- High-level progression stability tests.

### visual_tests_to_be_written
- `unlimited_upgrades_stone visual: level passes normal cap`

---

## 28. final_blow_stone

**name:** `final_blow_stone`
**description:** Last-round spike stone with strong conditional payout.

### implementation_details
- [ ] not implemented
- If played on final round: gain `+30 points` and `+10 plus_mult`.
- If not final round: gain only `+1 points`.
- Final round is defined by game mode round limit.

### animations_details
- [ ] not implemented
- Dramatic flash only on final-round trigger.

### heuristics_details
- [ ] not implemented
- Very high priority only when final round flag is true.

### tests
- [ ] not implemented
- Final vs non-final round behavior tests.

### visual_tests_to_be_written
- `final_blow_stone visual: final round huge payout`
- `final_blow_stone visual: earlier rounds only +1`

---

## 29. high_power_money_loss_stone

**name:** `high_power_money_loss_stone`
**description:** Tradeoff stone that gives strong score but costs money immediately.

### implementation_details
- [ ] not implemented
- On placement: gain `+12 points` and `+6 plus_mult`.
- Also lose `-8 money` immediately.
- If money would go negative, clamp to `0` and still apply score gains.

### animations_details
- [ ] not implemented
- Show green positive and red negative text together.

### heuristics_details
- [ ] not implemented
- Penalize use when money after placement would be `<5`.

### tests
- [ ] not implemented
- Simultaneous gain/loss and money clamp tests.

### visual_tests_to_be_written
- `high_power_money_loss_stone visual: positive and negative numbers both shown`

---

## 30. copper_stone

**name:** `copper_stone`
**description:** Low-power synergy stone. Alone it is weak, but it scales with synergy effects from stances/cards.

### implementation_details
- [ ] not implemented
- Base on placement: `+0 points`.
- Tag this stone with `copper` for external synergies.
- Built-in passive: if owner has 3+ copper stones on board, gain `+2 plus_mult` on each new copper placement.

### animations_details
- [ ] not implemented
- Minimal placement FX; stronger FX when 3+ copper threshold is active.

### heuristics_details
- [ ] not implemented
- Prefer only when copper count is near or above threshold.

### tests
- [ ] not implemented
- Threshold behavior tests for `0-2` vs `3+` copper count.

### visual_tests_to_be_written
- `copper_stone visual: no threshold no bonus`
- `copper_stone visual: threshold reached +2 plus_mult`

---

## 31. retrigger_stone

**name:** `retrigger_stone`
**description:** Replays a previously triggered stone effect to amplify combos. It does nothing if there is no valid target effect to replay.

### implementation_details
- [ ] not implemented
- On placement, look up the owner's most recent stone effect that resolved this turn.
- Exclusions: cannot retrigger `retrigger_stone` itself, and cannot retrigger effects marked `non_retriggerable`.
- Replay exactly once with same effective parameters and same owner.
- If no valid target exists, apply fallback `+1 points`.
- Trigger phase: immediate after normal placement effects (`playing_stones` tail priority).

### animations_details
- [ ] not implemented
- Show "RETRIGGER" text, then play target effect animation once.
- If fallback path, show `+1` only.

### heuristics_details
- [ ] not implemented
- High value when previous same-turn effect had large score swing.
- Low value when no valid retrigger target exists.

### tests
- [ ] not implemented
- Retriggers previous valid effect exactly once.
- Does not retrigger excluded effects.
- Fallback `+1 points` when no valid target.

### visual_tests_to_be_written
- `retrigger_stone visual: repeats prior wall payout effect`
- `retrigger_stone visual: cannot chain retrigger into retrigger`
- `retrigger_stone visual: empty-history fallback +1`
