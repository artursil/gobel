# PRD: Card Play UI Refactor

**Status:** ready-for-agent  
**Source:** Thermo-nuclear code quality review of commits `3dcbd6a`–`5efaa6d` (stone display + card play UI)  
**Triage label:** `ready-for-agent`

---

## Problem Statement

Card play UI works and correctly delegates legality to the resolver, but the implementation landed as a large state machine inside the LÖVE entry point and duplicated rendering paths in the draw layer. `main.lua` grew by ~540 lines and now exceeds 1,300 lines; `render.lua` exceeds 1,400. Card targeting state is mirrored in multiple places on `MatchState` (legacy single-target fields plus new multi-target lists), making the flow hard to extend and reason about. Deck/discard browser tiles use a placeholder draw path while hand cards use the full visual pipeline, so every card visual change requires two updates. The codebase already established a better pattern with stone display (dedicated modules for atlas, solidity, layout geometry), but card play did not follow it.

Developers and agents adding new cards, targeting modes, or UI polish will keep touching unrelated flows (menu, stone drag, stance drag, influence probe) and risk regressions. Tests exist but reach into `main.lua` closures via upvalue hacking, which couples specs to file layout rather than a testable module boundary.

## Solution

Restructure card play UI into focused modules that mirror the stone-display architecture: a **card play controller** owns selection, validation sync, drag/commit orchestration, and user-facing status; a **card draw module** owns all card face rendering (hand, focus popup, deck/discard browser); **layout helpers** own repeated popup grid geometry. Collapse targeting to a single source of truth injected into render. Reduce `main.lua` to LÖVE callback wiring only. Preserve all current player-visible behavior; this is a structural refactor, not a feature change.

## User Stories

1. As a player, I want to click a card in my hand to pop it into focus, so that I can read it and choose to play it without accidentally committing the play.
2. As a player, I want instant cards to show a Confirm action when selected, so that I explicitly commit zero-target plays.
3. As a player, I want single-target stone cards to let me pick a board stone by click or drag arrow, so that targeting feels direct on the board.
4. As a player, I want invalid stone targets to show clear feedback (message + highlight), so that I understand why a target was rejected.
5. As a player, I want multi-discard cards (e.g. Sale Prep) to use Use then pick hand cards then Confirm, so that the two-phase flow is obvious.
6. As a player, I want popped discard targets to enlarge in the hand fan, so that I can see which cards I selected.
7. As a player, I want to remove a selected target via target chips, so that I can correct mistakes before Confirm.
8. As a player, I want to drag a card toward the Use/Confirm button to arm or commit, so that mouse-heavy play matches click play.
9. As a player, I want stone-target drags to show a curved arrow from the focused card to the hovered target, so that drag targeting is visually guided.
10. As a player, I want invalid drag drops to cancel the play and keep the card selected, so that a bad release does not consume the card.
11. As a player, I want cards I cannot afford to appear visually dimmed, so that energy cost is obvious before I try to play.
12. As a player, I want the Use button label to read Use or Confirm appropriately, so that the next action is unambiguous.
13. As a player, I want requirement text (e.g. target count) near the action button, so that I know what is still needed.
14. As a player, I want hand hit-testing to prefer the topmost overlapping card in the fan, so that overlapped cards remain clickable.
15. As a developer, I want card legality to come only from `validate_card_targets` / `validate_card_target_candidate`, so that UI never duplicates resolver rules.
16. As a developer, I want card play logic in a require-able module, so that I can test flows without reaching into `main.lua` upvalues.
17. As a developer, I want one card face draw function used for hand, focus, and deck/discard popups, so that visual defs stay consistent.
18. As a developer, I want layout to expose deck popup grid rects once, so that draw and hit-test cannot drift apart.
19. As a developer, I want `main.lua` under ~900 lines after refactor, so that the entry point stays scannable.
20. As a developer, I want render’s hand/action-panel code deduplicated, so that button styling changes happen in one place.
21. As a developer, I want a explicit phase model for card UI (idle, card selected, discard targeting armed, drag modes), so that new play modes add states instead of boolean cross-checks.
22. As a developer, I want match state to hold gameplay snapshots only, not transient UI highlight copies, so that resolver and render boundaries stay clean.
23. As a maintainer, I want dead code removed (`card_is_targetable`, unused flat hand rects, redundant label branches), so that readers are not misled.
24. As a maintainer, I want integration specs to keep passing with minimal changes, so that refactor confidence is high.
25. As a future card author, I want new `play_mode` / `target_object_type` combinations to plug into the controller phase table, so that UI work does not require editing the LÖVE entry point.

## Implementation Decisions

### Module boundaries

- **New: card play controller module**  
  Owns ephemeral card UI state (selection, armed discard phase, drag, validation mirror, user messages, invalid-target feedback timer). Exposes a small API: `new()`, `reset()`, `on_press(x, y, ctx)`, `on_move(x, y, ctx)`, `on_release(x, y, ctx)`, `refresh(ctx)`, `try_commit()`, `state()` for render injection.  
  `ctx` bundles: `match`, `layout`, active player, and callbacks `play_card(hand_index, targets)` / read-only content lookups.  
  Does **not** call `resolve_round` or embed scoring logic.

- **New: card draw module**  
  Single entry: draw card face into a rect/slot (position, size, optional rotation, affordance dimming, highlight ring). Uses existing `card_geometry`, `card_layout`, `card_visual`, sprites. Replaces inline hand draw and placeholder popup tiles.

- **Modified: layout module**  
  Add shared helper for deck/discard popup played-card grid rects (same math currently duplicated in draw and popup hit-test). Keep hand fan slots, focus rect, use button rect, target chip rects as today.

- **Modified: main entry**  
  Instantiate controller at load/reset; delegate card-related mouse handlers; pass controller state to render via existing setter pattern. Remove ~400 lines of local card functions.

- **Modified: render module**  
  Consume controller state only for targeting highlights and action panel; remove duplicate Use-button draw blocks; call card draw module for hand, focus, floating drag, and deck/discard popups.

- **Modified: match state (minimal)**  
  Deprecate writing `selected_card_target` from board click path when multi-target `selected_targets` is active. Render reads targeting visuals from injected controller state, not duplicated match fields. Resolver legacy fallback for `selected_card_target` may remain until a follow-up removes it—do not break event paths that still commit via resolver events.

### Card UI phase model

Replace implicit boolean combinations with an explicit phase enum on controller state:

```lua
-- phases (controller internal)
"idle"
| "card_selected"           -- hand_index set, awaiting target or Confirm
| "discard_targets_armed"   -- hand card armed; picking other hand cards as targets
| "drag_to_confirm"         -- moved card toward action button
| "drag_target_arrow"       -- stone-target drag with arrow preview
```

Transitions preserve current behavior: Sale Prep arms into `discard_targets_armed`; stone cards enter `drag_target_arrow` on sufficient mouse movement; instant cards stay in `card_selected` until Confirm.

### Validation and messaging

- Controller calls resolver validators; never implements tag/owner/type checks locally.
- `map_validation_reason` stays UI-side but may later consume structured error codes if resolver adds them—out of scope for this PRD.
- `refresh(ctx)` computes: `can_use`, `validation_reason`, `requirement_text`, `action_button_label`, `selected_target_labels`. Does **not** cache layout chip rects; hit-test recomputes rects from layout at click time.

### Commit path unification

Single internal `try_commit(source)` used by button click, drag-to-confirm release, and drag-arrow valid release. All paths call the same `play_card` callback and `clear_after_play()`.

### Board click interaction

When controller phase is `card_selected` or `discard_targets_armed` and click is on a stone, toggle target via resolver candidate validation. **Decision:** suppress board stone info popup during active card targeting (popup remains available when no card flow is active). Document in further notes if product prefers popup + target together.

### Rendering unification

Deck browser, discard browser, and hand use the same card face drawer. Popup tiles may use a smaller rect but same pipeline (background, energy badge, art, title, description).

### Dead code removal

Remove unused `card_is_targetable`, redundant branches in action button label helper, and flat `hand_card_rects` if no production caller remains (update any spec still using it to fan slots).

### Architectural alignment (Gobel coding standards)

- Gameplay rules stay in effects + resolver; controller mirrors validation for buttons/hover only.
- Definitions immutable; instances/snapshots at play time unchanged.
- No new `if card_id ==` branches in UI.

## Testing Decisions

### What makes a good test here

- Test **external behavior** visible to the player or downstream game state: hand counts, discard pile, board solidity, energy spend, selected phase labels, commit success/failure.
- Do **not** assert internal controller field names unless through a stable public `state()` snapshot documented for render.
- Prefer testing through the controller module API once extracted; keep a thin integration spec that wires LÖVE stubs only if needed for regression parity.

### Testing seams (proposed — confirm before implementation)

Tests should sit at the **highest seam that still observes real behavior**:

| Seam | What it validates | Priority |
|------|-------------------|----------|
| **Integration: card UI flow** (existing) | End-to-end via stubbed LÖVE callbacks + layout; hand/disc/board clicks, drag, commit outcomes | Keep; reduce upvalue coupling by routing through controller export |
| **Unit: card play controller** (new) | Phase transitions, `refresh` → `can_use`/labels, `try_commit` calls `play_card` with correct targets, invalid target feedback | Primary new seam |
| **Unit: layout hand fan** (existing patterns) | `hand_index_at` topmost preference, fan slot geometry | Already covered in integration; optional unit if extracted |
| **Unit: card draw** (optional) | Smoke only if draw module exposes pure “layout regions computed” helpers; skip pixel assertions | Low — no pixel tests |

Existing prior art: `spec/integration/card_ui_flow_spec.lua` (Sale Prep, heal, attack, drag arrow, instant Confirm). Mirror its cases against controller API after extraction.

Regression gate: run affected `spec/integration/card_ui_flow_spec.lua` and any layout spec touched by `hand_card_rects` removal.

## Out of Scope

- New card definitions, effects, or targeting modes beyond what exists today.
- Resolver changes to error code shapes or removing `selected_card_target` event path entirely (follow-up).
- Stone display / atlas work (already in good shape).
- Stance drag, stone drag, influence probe, menu/home navigation refactors.
- Pixel/visual golden tests or art asset changes.
- AI/MCTS awareness of card UI (bots do not use this layer).
- Keyboard shortcuts `1`–`5` quick-play behavior change.
- Performance profiling of draw calls.

## Further Notes

- **Origin:** Code review flagged `main.lua` and `render.lua` file-size threshold breach and recommended “code judo” extraction mirroring stone modules.
- **Risk:** Highest regression area is mouse release handling (three commit paths today). Consolidating to `try_commit` must preserve drag-arrow instant commit vs drag-to-Confirm vs button click parity covered by existing integration specs.
- **Match state cleanup:** Prefer render injection over `match.selected_card_targets` / `match.card_target_hint_cells` copies; remove writes from controller refresh if render can derive hints from controller `state().selected_targets`.
- **Issue tracker:** Publish this document as a GitHub issue with label `ready-for-agent` when `gh` CLI is available; until then this file is the canonical PRD.
- **Agent handoff:** Code Writer implements; no AI planner redesign required—behavior is frozen, structure changes only.
