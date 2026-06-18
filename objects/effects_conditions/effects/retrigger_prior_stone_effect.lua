--- Replay prior retriggerable same-turn stone effect or fallback points.
--- @module objects.effects_conditions.effects.retrigger_prior_stone_effect

local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")

local NON_RETRIGGERABLE_STONE_IDS = { retrigger_stone = true }
local NON_RETRIGGERABLE_EFFECT_NAMES = {
	retrigger_prior_stone_effect = true,
	self_destruct_setup = true,
}

local M = {}

local function retrigger_is_stone(stone_id)
	return NON_RETRIGGERABLE_STONE_IDS[stone_id] ~= true
end

local function retrigger_is_effect(effect_name)
	return NON_RETRIGGERABLE_EFFECT_NAMES[effect_name] ~= true
end

local function retrigger_side_from_owner(owner)
	if owner == config.OWNER_WHITE then
		return "white"
	end
	return "black"
end

local function retrigger_is_board_replay(effect_def)
	local name = effect_def.effect_name
	return name == "wall_stone"
		or name == "diagonal_group_points"
		or name == "line_group_points"
		or name == "money_field_enclosure_payout"
		or name == "pattern_x_mult"
		or name == "pattern_plus_mult"
end

local function retrigger_find_prior(state, owner)
	local events = state.round_stone_effects
	if not events or #events == 0 then
		return nil
	end
	for i = #events - 1, 1, -1 do
		local event = events[i]
		if event.owner == owner and retrigger_is_stone(event.stone_type) then
			return event
		end
	end
	return nil
end

local function retrigger_replay_def(state, owner, event, effect_def)
	if not retrigger_is_effect(effect_def.effect_name) then
		return
	end
	local row = event.row
	local col = event.col
	local prev_move = state.last_opponent_move
	local side = retrigger_side_from_owner(owner)
	state.last_opponent_move = {
		stone_id = event.stone_type,
		row = row,
		col = col,
		actor = side,
	}
	local registry = require("objects.effects_conditions.effects")
	local resolved = registry.resolve(effect_def)
	if resolved and resolved.apply then
		local scoring_phases = require("single_game.resolver.scoring_phases")
		if not retrigger_is_board_replay(effect_def) and scoring_phases.is_board_territory_effect(effect_def) then
		else
			require("objects.effects_conditions.run").apply_effect(resolved, state, owner)
		end
	end
	state.last_opponent_move = prev_move
end

local function retrigger_replay_event(state, owner, event)
	state._retrigger_replay_depth = (state._retrigger_replay_depth or 0) + 1
	if state._retrigger_replay_depth > 1 then
		state._retrigger_replay_depth = state._retrigger_replay_depth - 1
		return
	end
	local replayed = {}
	for i = 1, #(event.effects or {}) do
		local effect_def = event.effects[i]
		retrigger_replay_def(state, owner, event, effect_def)
		if retrigger_is_board_replay(effect_def) then
			replayed[effect_def.effect_name] = true
		end
	end
	local content = require("content")
	local stone_def = content.get_stone(event.stone_type)
	if stone_def and stone_def.effects then
		for i = 1, #stone_def.effects do
			local effect_def = stone_def.effects[i]
			if retrigger_is_board_replay(effect_def) and not replayed[effect_def.effect_name] then
				retrigger_replay_def(state, owner, event, effect_def)
			end
		end
	end
	state._retrigger_replay_depth = state._retrigger_replay_depth - 1
end

local function retrigger_apply_or_fallback(state, owner)
	if state._retrigger_replay_depth and state._retrigger_replay_depth > 0 then
		return
	end
	local prior = retrigger_find_prior(state, owner)
	if not prior then
		state.scores.points[owner] = state.scores.points[owner] + stone_params.retrigger_fallback_points
		return
	end
	retrigger_replay_event(state, owner, prior)
end

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "RETRIGGER_PRIOR_STONE_EFFECT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			retrigger_apply_or_fallback(state, owner)
		end,
	}
end

return M
