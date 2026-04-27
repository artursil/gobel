-- =========================
-- CONFIG / ENUMS
-- =========================
PHASES = { "territory", "points", "mult", "post" }

-- =========================
-- STATE
-- =========================
state = {
    scores = {
        territory = {A = 0, B = 0},
        points = {A = 0, B = 0},
        mult = {A = 1, B = 1}
    },

    poses = {},
    modifiers = {}, -- cards played this turn

    last_played_stone = nil,
    current_player = "A"
}

-- =========================
-- EFFECT REGISTRY
-- =========================
Effects = {}

-- Pose A: +10 mult
Effects.poseA = function(pose, state)
    return {
        {
            phase = "mult",
            priority = 10,
            apply = function(state)
                print("[Pose A] +10 mult triggered")
                state.scores.mult[pose.owner] =
                    state.scores.mult[pose.owner] + 10
            end
        }
    }
end

-- Pose B: +3 points if anchor played
Effects.poseB = function(pose, state)
    return {
        {
            phase = "points",
            priority = 10,
            apply = function(state)
                if state.last_played_stone == "anchor" then
                    print("[Pose B] +3 points (anchor condition met)")
                    state.scores.points[pose.owner] =
                        state.scores.points[pose.owner] + 3
                else
                    print("[Pose B] skipped (no anchor)")
                end
            end
        }
    }
end

-- Pose C: +2 flat points
Effects.poseC = function(pose, state)
    return {
        {
            phase = "points",
            priority = 5,
            apply = function(state)
                print("[Pose C] +2 points")
                state.scores.points[pose.owner] =
                    state.scores.points[pose.owner] + 2
            end
        }
    }
end

-- Pose D: +1 mult per card played
Effects.poseD = function(pose, state)
    return {
        {
            phase = "mult",
            priority = 5,
            apply = function(state)
                local bonus = #state.modifiers
                print("[Pose D] +" .. bonus .. " mult (cards played)")
                state.scores.mult[pose.owner] =
                    state.scores.mult[pose.owner] + bonus
            end
        }
    }
end

-- =========================
-- BLUEPRINT (CHAIN SAFE)
-- =========================
function resolve_blueprint_target(state, start_index)
    local i = start_index + 1
    while i <= #state.poses do
        local target = state.poses[i]
        if target.type ~= "blueprint" then
            return target
        end
        i = i + 1
    end
    return nil
end

Effects.blueprint = function(pose, state)
    local target = resolve_blueprint_target(state, pose.index)

    if not target then
        print("[Blueprint] no target")
        return {}
    end

    print("[Blueprint] copying -> " .. target.type)

    local generator = Effects[target.type]
    if not generator then return {} end

    return generator(target, state)
end

-- =========================
-- CARD (modifier)
-- =========================
Effects.card_boost = function(card, state)
    return {
        {
            phase = "points",
            priority = 1,
            apply = function(state)
                print("[Card] +5 points")
                state.scores.points[state.current_player] =
                    state.scores.points[state.current_player] + 5
            end
        }
    }
end

-- =========================
-- EFFECT COLLECTION
-- =========================
function collect_effects(state, phase)
    local effects = {}

    -- poses
    for i, pose in ipairs(state.poses) do
        pose.index = i

        local generator = Effects[pose.type]
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
    for _, card in ipairs(state.modifiers) do
        local generator = Effects[card.type]
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

function apply_phase(state, phase)
    print("\n== Phase:", phase, "==")

    local effects = collect_effects(state, phase)

    for _, e in ipairs(effects) do
        e.apply(state)
    end
end

-- =========================
-- DUMMY TERRITORY
-- =========================
function calculate_territory(state)
    print("[System] Calculating territory (dummy)")
    state.scores.territory.A = 10
    state.scores.territory.B = 8
end

-- =========================
-- MAIN RESOLUTION
-- =========================
function resolve_turn(state)
    calculate_territory(state)

    for _, phase in ipairs(PHASES) do
        apply_phase(state, phase)
    end

    -- final score
    local A = state.scores.territory.A * state.scores.mult.A + state.scores.points.A
    local B = state.scores.territory.B * state.scores.mult.B + state.scores.points.B

    print("\n=== FINAL SCORE ===")
    print("A:", A, "| B:", B)
end

-- =========================
-- SETUP TEST
-- =========================

-- poses in hand:
-- [Blueprint][Blueprint][Pose B][Pose A][Pose D]
state.poses = {
    {type = "blueprint", owner = "A"},
    {type = "blueprint", owner = "A"},
    {type = "poseB", owner = "A"},
    {type = "poseA", owner = "A"},
    {type = "poseD", owner = "A"}
}

-- simulate playing a card
table.insert(state.modifiers, {type = "card_boost"})

-- simulate placing a stone
state.last_played_stone = "anchor"

-- =========================
-- RUN
-- =========================
resolve_turn(state)