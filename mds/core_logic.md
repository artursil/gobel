# 🧠 CODE WRITER AGENT — INCREMENTAL INSTRUCTIONS

## 🚫 IMPORTANT

* Do NOT restructure the whole project
* Do NOT replace existing systems unless necessary
* Extend current code to support **effect-based resolution**
* Keep changes minimal, modular, and reversible

---

# 🎯 GOAL

Introduce a **phase-based effect system** that supports:

* poses (passives)
* playing cards (modifiers)
* stones (effects later)

while remaining compatible with existing code.

---

# 🧱 1. STATE — MINIMAL EXTENSIONS ONLY

Do NOT redefine `state`.

Only ensure the following fields exist (add if missing):

```lua
state.poses        -- ordered list (important for Blueprint)
state.modifiers    -- cards played this turn
state.last_played_stone
state.scores = state.scores or {
    territory = {A = 0, B = 0},
    points = {A = 0, B = 0},
    mult = {A = 1, B = 1}
}
```

If these already exist → reuse them.

---

# 🔁 2. PHASE SYSTEM (ADD, DO NOT REPLACE)

Introduce phases:

```lua
PHASES = { "pre", "territory", "points", "mult", "post" }
```

Wherever scoring currently happens, wrap it like:

```lua
calculate_territory(state)

for _, phase in ipairs(PHASES) do
    apply_phase(state, phase)
end

calculate_final_score(state)
```

Do NOT remove existing logic—just insert phase handling around it.

---


---

# 📁 4. FILE ORGANIZATION
Have a following file structure
- stones
  - definitions.lua
  - effects.lua
- playing_cards
  - definitions.lua
  - effects.lua
- poses
  - definitions.lua
  - effects.lua

---

# � 5. EFFECT FORMAT (MANDATORY)

Every effect must return:

```lua
{
    phase = "points",
    priority = 10,
    apply = function(state) end
}
```

---

# 🔁 6. EFFECT COLLECTION

Add a function (new file or existing system):

```lua
function collect_effects(state, phase)
    local effects = {}

    -- poses
    for i, pose in ipairs(state.poses or {}) do
        pose.index = i

        local generator = Effects.poses[pose.type]
        if generator then
            local generated = generator(pose, state)

            for _, e in ipairs(generated) do
                if e.phase == phase then
                    table.insert(effects, e)
                end
            end
        end
    end

    -- cards
    for _, card in ipairs(state.modifiers or {}) do
        local generator = Effects.cards[card.type]
        if generator then
            local generated = generator(card, state)

            for _, e in ipairs(generated) do
                if e.phase == phase then
                    table.insert(effects, e)
                end
            end
        end
    end

    table.sort(effects, function(a, b)
        return a.priority < b.priority
    end)

    return effects
end
```

---

# ▶️ 7. APPLY PHASE

```lua
function apply_phase(state, phase)
    local effects = collect_effects(state, phase)

    for _, effect in ipairs(effects) do
        effect.apply(state)
    end
end
```

---


# 🧪 9. DEBUGGING (REQUIRED)

Each effect should log when triggered:

```lua
print("[Effect Triggered]", pose.type, phase)
```

Keep logs simple and consistent.

---

# 🧱 10. TERRITORY (TEMP)

Do NOT modify existing logic.


---

# 🧠 11. DESIGN RULES (STRICT)

* No direct interaction between objects
* No effect calling another effect
* No hidden global state
* All logic flows through phases
* Order = priority only

---

# 🎯 FINAL PRINCIPLE

> We are layering an **effect system on top of existing logic**,
> not rewriting the engine.

---

# ✅ TASK

1. Add effect registry
2. Add phase execution

4. Ensure everything runs through phases
5. Keep changes minimal and localized

Do NOT expand beyond this.
