--- Retrigger stone: replay prior same-turn stone payout for the placing owner.
--- @module single_game.resolver.retrigger_stone

local config = require("config")
local content = require("content")
local stone_params = require("objects.parameters.stones")
local objects_effects = require("objects.effects")
local scoring_phases = require("single_game.resolver.scoring_phases")

local M = {}

M.NON_RETRIGGERABLE_STONE_IDS = {
	retrigger_stone = true,
}

M.NON_RETRIGGERABLE_EFFECT_NAMES = {
	retrigger_prior_stone_effect = true,
	self_destruct_timed = true,
}

--- @param stone_id string
--- @return boolean
function M.is_retriggerable_stone(stone_id)
	return M.NON_RETRIGGERABLE_STONE_IDS[stone_id] ~= true
end

--- @param effect_name string
--- @return boolean
function M.is_retriggerable_effect_name(effect_name)
	return M.NON_RETRIGGERABLE_EFFECT_NAMES[effect_name] ~= true
end

--- @param side string
--- @return string
local function owner_from_side(side)
	if side == "white" then
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- @param owner string
--- @return string
local function side_from_owner(owner)
	if owner == config.OWNER_WHITE then
		return "white"
	end
	return "black"
end

--- Walk ``round_stone_effects`` from newest to oldest, skipping the current placement tail.
--- @param state table
--- @param owner string
--- @return table|nil
function M.find_prior_retriggerable_event(state, owner)
	local events = state.round_stone_effects
	if not events or #events == 0 then
		return nil
	end
	local last_index = #events
	for i = last_index - 1, 1, -1 do
		local event = events[i]
		if event.owner == owner and M.is_retriggerable_stone(event.stone_type) then
			return event
		end
	end
	return nil
end

--- @param effect_def table
--- @return boolean
local function is_board_replay_effect(effect_def)
	local name = effect_def.effect_name
	return name == "wall_stone"
		or name == "diagonal_group_points"
		or name == "line_group_points"
		or name == "money_field_enclosure_payout"
		or name == "pattern_x_mult"
		or name == "pattern_plus_mult"
end

--- Re-applies one resolved placement/board effect while pretending the prior stone was just placed.
--- @param state table
--- @param owner string
--- @param event table
--- @param effect_def table
--- @return nil
local function replay_effect_def(state, owner, event, effect_def)
	if not M.is_retriggerable_effect_name(effect_def.effect_name) then
		return
	end
	local row = event.row
	local col = event.col
	local prev_move = state.last_opponent_move
	local side = side_from_owner(owner)
	state.last_opponent_move = {
		stone_id = event.stone_type,
		row = row,
		col = col,
		actor = side,
	}
	if is_board_replay_effect(effect_def) and row and col then
		local resolved = objects_effects.resolve(effect_def)
		if resolved and resolved.apply then
			if resolved.type == "WALL_STONE"
				or resolved.type == "DIAGONAL_GROUP_POINTS"
				or resolved.type == "LINE_GROUP_POINTS"
				or resolved.type == "MONEY_FIELD_ENCLOSURE_PAYOUT" then
				resolved.apply(state, owner, row, col)
			else
				resolved.apply(state, owner)
			end
		end
	else
		local resolved = objects_effects.resolve(effect_def)
		if resolved and resolved.apply and not scoring_phases.is_board_territory_effect(effect_def) then
			resolved.apply(state, owner)
		end
	end
	state.last_opponent_move = prev_move
end

--- Replays resolved defs from the prior event, then board-scoped defs from the stone definition.
--- @param state table
--- @param owner string
--- @param event table
--- @return nil
function M.replay_prior_event(state, owner, event)
	state._retrigger_replay_depth = (state._retrigger_replay_depth or 0) + 1
	if state._retrigger_replay_depth > 1 then
		state._retrigger_replay_depth = state._retrigger_replay_depth - 1
		return
	end
	for i = 1, #(event.effects or {}) do
		replay_effect_def(state, owner, event, event.effects[i])
	end
	local stone_def = content.get_stone(event.stone_type)
	if stone_def and stone_def.effects then
		for i = 1, #stone_def.effects do
			local effect_def = stone_def.effects[i]
			if is_board_replay_effect(effect_def) then
				replay_effect_def(state, owner, event, effect_def)
			end
		end
	end
	state._retrigger_replay_depth = state._retrigger_replay_depth - 1
end

--- @param state table
--- @param owner string
--- @return nil
function M.apply_retrigger_or_fallback(state, owner)
	if state._retrigger_replay_depth and state._retrigger_replay_depth > 0 then
		return
	end
	local prior = M.find_prior_retriggerable_event(state, owner)
	if not prior then
		state.scores.points[owner] = state.scores.points[owner] + stone_params.retrigger_fallback_points
		return
	end
	M.replay_prior_event(state, owner, prior)
end

return M
