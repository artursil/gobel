local config = require("config")
local match_state = require("match_state")
local phases = require("resolver.phases")
local effect_manager = require("resolver.effect_manager")
local territory = require("resolver.territory")
local scoring = require("scoring")

local M = {}

local function ensure_state_fields(state)
	state.last_opponent_move = state.last_opponent_move or nil
	state.last_opponent_modifiers = state.last_opponent_modifiers or {}
	state.active_effects = state.active_effects or {}
	state.round_stone_effects = state.round_stone_effects or {}
	state.poses = state.poses or {}
	state.modifiers = state.modifiers or {}
	state.last_played_stone = state.last_played_stone or nil
	state.scores = state.scores or {
		territory = { A = 0, B = 0 },
		points = { A = 0, B = 0 },
		mult = { A = 1, B = 1 },
	}
end

local function sync_opponent_state(state)
	state.last_opponent_move = state.last_opponent_move or nil
	state.last_opponent_modifiers = state.last_opponent_modifiers or {}
end

local function side_to_owner(side)
	if side == "white" then
		return "B"
	end
	return "A"
end

local function rebuild_ordered_poses(state)
	local ordered = {}
	for _, side in ipairs({ "black", "white" }) do
		local player = match_state.player_for_color(state, side)
		for _, pose_id in ipairs(player.poses.fixed or {}) do
			ordered[#ordered + 1] = { type = pose_id, owner = side_to_owner(side) }
		end
		for _, pose_id in ipairs(player.poses.swappable or {}) do
			ordered[#ordered + 1] = { type = pose_id, owner = side_to_owner(side) }
		end
	end
	state.poses = ordered
end

local function reset_base_scores(state)
	local black = match_state.player_for_color(state, "black")
	local white = match_state.player_for_color(state, "white")
	state.scores.points.A = black.score.points_bonus or 0
	state.scores.points.B = white.score.points_bonus or 0
	state.scores.mult.A = scoring.overall_mult(state.board, config.STONE_BLACK) + (black.score.mult_bonus or 0)
	state.scores.mult.B = scoring.overall_mult(state.board, config.STONE_WHITE) + (white.score.mult_bonus or 0)
end

local function sync_player_scores(state)
	local black = match_state.player_for_color(state, "black")
	local white = match_state.player_for_color(state, "white")
	black.score.territory = state.scores.territory.A
	black.score.points = state.scores.points.A
	black.score.mult = state.scores.mult.A
	black.score.total = (black.score.territory + black.score.points) * black.score.mult
	white.score.territory = state.scores.territory.B
	white.score.points = state.scores.points.B
	white.score.mult = state.scores.mult.B
	white.score.total = (white.score.territory + white.score.points) * white.score.mult
end

local function tick_timed_effects(state)
	local kept = {}
	for _, active in ipairs(state.active_effects) do
		active.remaining_turns = active.remaining_turns - 1
		if active.remaining_turns > 0 then
			kept[#kept + 1] = active
		end
	end
	state.active_effects = kept
end

function M.resolve(state)
	ensure_state_fields(state)
	sync_opponent_state(state)
	rebuild_ordered_poses(state)
	reset_base_scores(state)
	for _, phase in ipairs(phases.PRE) do
		effect_manager.apply_phase(state, phase)
	end
	for _, phase in ipairs(phases.MAIN) do
		if phase == "territory" then
			territory.calculate_base(state)
		end
		effect_manager.apply_phase(state, phase)
	end
	sync_player_scores(state)
	state.round_stone_effects = {}
	tick_timed_effects(state)
end

return M
