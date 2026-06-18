# Effects–conditions module — glossary & invariants

Local context for `objects/effects_conditions/`. Domain-wide terms live in the repo root `CONTEXT.md`. Normative pipeline detail: `docs/effects-architecture.md`, ADR 0001, **ADR 0003**.

**PRD:** GitHub issue #42

---

## Purpose

Single home for effect and condition **schemas**, **per-name effect/condition files**, thin **registries**, **runner**, and **shared helpers**.

## Apply orchestration

Each `effects/<name>.lua` exports `build(effect)` only. The returned table includes **`apply = function(state, owner, kwargs) ... end`** — an inline function, not `M.apply`. Typically 3–8 lines: `require_kwargs` → shared helper calls → optional animation. `effect.value` and other def fields are read from the `effect` argument inside `build` (closure). Logic lives in `helpers/shared/`. File opens with a detailed module docstring.

## Duration left

**Board cells (stones):** `cell.duration_left` — set by an `on_play` effect. Initial value comes from the **effect row on the definition**, which references **`objects/parameters/*`** (e.g. `rounds = P.points_delay_rounds`) — never hardcoded in effect files.

**Schema (strict):** any effect row that sets `duration_left` on play **must** declare `rounds` or `duration` on the definition row. Load-time validation fails if missing — no silent fallback to parameters inside the effect builder.

**Multiple effect rows per object:** Differ by **`action`** (`on_play`, `tick`, `end_of_turn`, `on_removed`, …). Each resolves to **`apply` only**.

**Timed stones (naming):** use **separate `effect_name`s per beat** — e.g. `delay_reward_setup` (`on_play`) + `delay_reward_payout` (`tick`) — one file each under `effects/`. Do not reuse one `effect_name` with an `if action` branch in `build`, and do not use `_tick` suffix hacks on the name.

**Self-destruct:** `self_destruct_setup` + `self_destruct_expire`; expire **enqueues** on `pending_stone_removals`.

**Anti-capture:** `anti_capture_setup` + `anti_capture_expire`; expire no-op, **no enqueue**.

**`action = tick` row:** Separate def row; collected when `cell.duration_left ~= nil`. `apply` handles expiry when `duration_left == 0` after decrement.

**ObjectInstance:** `instance.duration.remaining_rounds` from parameters via def (stances/cards).

Blockade timers on adjacent empty cells stay in `placement_blocks` (exception).

## Registry layout

Per-name files under `effects/` and `conditions/`. Registries route only. Reusable math in `helpers/shared/`.

## Registry docstring

Lives at the **top of each** `effects/<name>.lua` and `conditions/<name>.lua` file — not on the thin `effects.lua` / `conditions.lua` registry. Explains resolver behavior in full. Not `@param` type lists. Player-facing copy stays on object definitions.

## Helper roles

| Area | Responsibility |
|------|----------------|
| `effects/<name>.lua` | Module docstring + `build(effect)` → table with inline `apply = function(...)` |
| `conditions/<name>.lua` | Module docstring + `eval` (first/only entry function) |
| `effects.lua` / `conditions.lua` | Registry only: require + route by name |
| `helpers/shared/` | Reusable math used by multiple effects or conditions |

Complex computation never lives in the resolver.

## Runner

The only path from the resolver effect manager to `apply`. Flow: evaluate all conditions → merge kwargs fragments → one `apply(state, owner, kwargs)` or skip.

Direct helper calls from resolver code are forbidden.

## Removal beat

Effects may enqueue on `pending_stone_removals` and/or register animations. Order: **effects → animation → drain queue (removal last)**. On-play, card attack, and EOT tick all follow this beat.

**Damage cards:** apply mutates solidity; at 0 enqueue removal without clearing the cell until post-animation drain.

**Capture stone:** regular Go captures at commit first; supplemental target from condition kwargs `{ row, col }`; effect enqueues only that extra cell.

## Condition eval contract

`eval(state, owner, condition_def) → pass: boolean, fragment: table | nil` in `conditions/<name>.lua`.

## Effect apply contract

`apply(state, owner, kwargs)` — always three arguments.

## Kwargs merge

Multiple conditions on one effect may each return a fragment. All must pass. Fragments merge into one `kwargs` table.

**Selected board target:** card effects read `state.resolution.selected_target(s)` inside `helpers/shared/selected_stone.lua`. Conditions (`selected_target_exists`, enemy/friendly) gate only — no target coords in kwargs. Attack/Heal omit def-row conditions; Destroy/Forge keep them. Contrast wall stone: condition returns computed `{ blocks = n }`.

## Effect schema

Validates effect definition rows at load time only. Owns action/phase enums. Documented in `EffectSchema.md`. Does not build or wrap resolved instances.

## Resolved runtime effect (fixed shape)

Returned by `effects/<name>.lua` `build(effect)`:

| Field | Role |
|-------|------|
| `type` | Uppercase kind (e.g. `"WALL_STONE"`) |
| `action`, `phase` | Scheduling (enums; def overrides builder defaults) |
| `priority`, `value`, … | Copied from definition |
| `conditions` | Runner gates |
| `apply(state, owner, kwargs)` | Inline orchestration → `helpers/shared/*` |

Forbidden: `on_tick`, `accepts_kwargs`, `_effect_def`, `macro`, `sub`, `kwargs_from_def`.

## Invariants

1. One file per `effect_name` (`effects/`) and per `condition_name` (`conditions/`).
2. Effects export `build` only; `apply` is always an inline function on the returned table.
3. No business logic in registry `effects.lua` / `conditions.lua`.
4. Runner is the sole apply entry from resolver.
5. Apply arity is always `(state, owner, kwargs)`; kwargs from conditions only.
6. Effect def fields passed via `build` closure, not kwargs.
7. Reused logic only in `helpers/shared/`.

## Navigation

Object def → `effects.lua` `M.resolve` → `effects/<name>.lua` `build` → runner → `conditions.lua` `M.eval` → `conditions/<name>.lua` `eval` → `apply`.
