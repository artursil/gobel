-- =========================
-- CONFIG / ENUMS
-- =========================
PHASES = { "territory", "points", "mult", "post" }

-- =========================
-- STATE
-- =========================
state = {
    scores = {
        territory = {B = 0, W = 0},
        points = {B = 0, W = 0},
        mult = {B = 1, W = 1}
    },

    players = {
        black = { stances = { fixed = {}, swappable = {} } },
        white = { stances = { fixed = {}, swappable = {} } },
    },
    temporary_stances = {},
    just_played = {},
    played_cards = {},

    last_played_stone = nil,
    current_player = "B"
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
                local bonus = #state.just_played
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
    local rows = state._stance_effect_order or {}
    local i = start_index + 1
    while i <= #rows do
        local target = rows[i]
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

    local stance_order = require("single_game.resolver.stance_order")
    local rows = stance_order.flatten_stances_for_resolve(state)

    for i, stance in ipairs(rows) do
        stance.index = stance.index or i

        local generator = Effects[stance.type]
        if generator then
            local generated = generator(stance, state)

            for _, e in ipairs(generated) do
                if e.phase == phase then
                    table.insert(effects, e)
                end
            end
        end
    end

    -- cards
    for _, card in ipairs(state.just_played) do
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
    state.scores.territory.B = 10
    state.scores.territory.W = 8
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
    local black_total = state.scores.territory.B * state.scores.mult.B + state.scores.points.B
    local white_total = state.scores.territory.W * state.scores.mult.W + state.scores.points.W

    print("\n=== FINAL SCORE ===")
    print("Black:", black_total, "| White:", white_total)
end

-- =========================
-- SETUP TEST
-- =========================

state.players = {
    black = {
        stances = {
            fixed = { "blueprint", "blueprint", "poseB", "poseA", "poseD" },
            swappable = {},
        },
    },
    white = { stances = { fixed = {}, swappable = {} } },
}
state.temporary_stances = {}
require("single_game.resolver.stance_order").flatten_stances_for_resolve(state)

-- simulate playing a card
table.insert(state.just_played, {type = "card_boost"})

-- simulate placing a stone
state.last_played_stone = "anchor"

-- =========================
-- RUN
-- =========================
resolve_turn(state)