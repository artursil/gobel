# CONTENT.md

## Purpose

This document defines the MVP content set for a single playable match.
All effects are intentionally basic and limited to score modification only.

## Design Constraint (MVP)

Allowed effect types:
- `ADD_POINTS`
- `ADD_MULT`

Not allowed in this content set:
- resource gain/spend effects
- draw/discard manipulation
- capture rule changes
- targeting complexity
- conditional triggers

## Stone Definitions (3)

Stones are placed on the board and may grant an immediate placement bonus.
Each placement bonus is applied in `RESOLVE_PHASE` after legal placement.

### STONE_BASIC

- id: `stone_basic`
- display_name: `Basic Stone`
- placement_effect:
  - type: `ADD_POINTS`
  - value: `1`
- notes:
  - baseline, always useful

### STONE_POWER

- id: `stone_power`
- display_name: `Power Stone`
- placement_effect:
  - type: `ADD_POINTS`
  - value: `2`
- notes:
  - stronger point-focused placement stone

### STONE_FOCUS

- id: `stone_focus`
- display_name: `Focus Stone`
- placement_effect:
  - type: `ADD_MULT`
  - value: `1`
- notes:
  - simple multiplier-focused placement stone

## Playing Card Definitions (5)

Cards can be played in `MAIN_PHASE` only.
All cards are single-step immediate effects.
After play, cards move from hand to discard.

### CARD_POINT_TAP

- id: `card_point_tap`
- display_name: `Point Tap`
- energy_cost: `1`
- effect:
  - type: `ADD_POINTS`
  - value: `2`

### CARD_POINT_PUSH

- id: `card_point_push`
- display_name: `Point Push`
- energy_cost: `2`
- effect:
  - type: `ADD_POINTS`
  - value: `4`

### CARD_SMALL_MULT

- id: `card_small_mult`
- display_name: `Small Mult`
- energy_cost: `1`
- effect:
  - type: `ADD_MULT`
  - value: `1`

### CARD_BIG_MULT

- id: `card_big_mult`
- display_name: `Big Mult`
- energy_cost: `2`
- effect:
  - type: `ADD_MULT`
  - value: `2`

### CARD_BALANCED_BOOST

- id: `card_balanced_boost`
- display_name: `Balanced Boost`
- energy_cost: `2`
- effect:
  - type: `ADD_POINTS`
  - value: `2`
- extra_effect:
  - type: `ADD_MULT`
  - value: `1`

## Pose Definitions (3)

Poses are always-on passives for the match.
For MVP, all pose effects are flat score modifiers triggered at `TURN_START`.

### POSE_POINT_STANCE

- id: `pose_point_stance`
- display_name: `Point Stance`
- category: `fixed_or_swappable`
- trigger: `TURN_START`
- effect:
  - type: `ADD_POINTS`
  - value: `1`

### POSE_MULT_STANCE

- id: `pose_mult_stance`
- display_name: `Mult Stance`
- category: `fixed_or_swappable`
- trigger: `TURN_START`
- effect:
  - type: `ADD_MULT`
  - value: `1`

### POSE_HEAVY_POINT_STANCE

- id: `pose_heavy_point_stance`
- display_name: `Heavy Point Stance`
- category: `fixed_or_swappable`
- trigger: `TURN_START`
- effect:
  - type: `ADD_POINTS`
  - value: `2`

## Starter Loadout (MVP)

This section defines the initial content for both sides in one match.

### Player Starter

- poses:
  - fixed:
    - `pose_point_stance`
  - swappable:
    - `pose_mult_stance`
- pouch:
  - `stone_basic` x6
  - `stone_power` x3
  - `stone_focus` x3
- deck:
  - `card_point_tap` x3
  - `card_point_push` x2
  - `card_small_mult` x2
  - `card_big_mult` x1
  - `card_balanced_boost` x2

### Opponent Starter

- poses:
  - fixed:
    - `pose_mult_stance`
  - swappable:
    - `pose_heavy_point_stance`
- pouch:
  - `stone_basic` x6
  - `stone_power` x3
  - `stone_focus` x3
- deck:
  - `card_point_tap` x3
  - `card_point_push` x2
  - `card_small_mult` x2
  - `card_big_mult` x1
  - `card_balanced_boost` x2

## Resolver Contract Notes

Implementation must convert content effects into resolver events with:
- message first
- state mutation second
- score recomputation third

Message examples:
- `Point Tap: +2 points`
- `Small Mult: +1 mult`
- `Basic Stone placement: +1 points`
- `Point Stance: +1 points`

