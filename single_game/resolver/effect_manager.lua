--- Coordinates stance, card, stone, and timed effects by macro/sub phase; sorts by priority; applies.
--- @module resolver.effect_manager

local board = require("board")
local config = require("config")
local effects_registry = require("effect_registry")
local dbg = require("debugger")
local queries = require("single_game.resolver.state_queries")
local scoring_phases = require("single_game.resolver.scoring_phases")
local stance_order = require("single_game.resolver.stance_order")

local M = {}

--- @param payload table
--- @return string|nil
local function sub_from_payload(payload)
	if payload.sub then
		return payload.sub
	end
	if payload.phase == "distance" or payload.phase == "territory" then
		return "territory"
	end
	if payload.phase == "points" then
		return "points"
	end
	if payload.phase == "mult" then
		return "mult"
	end
	return nil
end

--- @param effect_def table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @return boolean
local function def_matches(effect_def, active_macro, active_sub, territory_step)
	return scoring_phases.matches(effect_def, active_macro, active_sub, territory_step)
end

--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_stance_effects(state, active_macro, active_sub, territory_step, out)
	local rows = stance_order.flatten_stances_for_resolve(state)
	for _, stance in ipairs(rows) do
		local i = stance.index
		local generated = effects_registry.stances.resolve(stance, state)
		for _, e in ipairs(generated) do
			local effect_def = e._effect_def
			if effect_def and def_matches(effect_def, active_macro, active_sub, territory_step) then
				e.meta = e.meta or {}
				e.meta.source_owner = stance.owner
				e.meta.source_object_type = "stance"
				e.meta.source_stance_index = i
				e.meta.source_stance_slot_index = stance.slot_index
				e.meta.source_instance_id = stance.instance and stance.instance.instance_id or nil
				e.meta.source_def_id = stance.type
				table.insert(out, e)
			elseif not effect_def and e.sub == active_sub and (e.macro == active_macro or (not e.macro and active_macro == "playing_stones")) then
				e.meta = e.meta or {}
				e.meta.source_owner = stance.owner
				e.meta.source_object_type = "stance"
				e.meta.source_stance_index = i
				e.meta.source_stance_slot_index = stance.slot_index
				e.meta.source_instance_id = stance.instance and stance.instance.instance_id or nil
				e.meta.source_def_id = stance.type
				table.insert(out, e)
			end
		end
	end
end

--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_card_effects(state, active_macro, active_sub, territory_step, out)
	if active_macro ~= "playing_cards" then
		return
	end
	for _, card in ipairs(state.just_played or {}) do
		local generated = effects_registry.cards.resolve(card, state)
		for _, e in ipairs(generated) do
			local effect_def = e._effect_def
			if effect_def and def_matches(effect_def, active_macro, active_sub, territory_step) then
				e.meta = e.meta or {}
				e.meta.source_owner = card.owner
				e.meta.source_object_type = "card"
				e.meta.source_def_id = card.type
				e.meta.selected_target = card.selected_target
				table.insert(out, e)
			elseif not effect_def and sub_from_payload(e) == active_sub and (e.macro == active_macro or active_macro == "playing_cards") then
				e.meta = e.meta or {}
				e.meta.source_owner = card.owner
				e.meta.source_object_type = "card"
				e.meta.source_def_id = card.type
				e.meta.selected_target = card.selected_target
				table.insert(out, e)
			end
		end
	end
end

--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_stone_round_effects(state, active_macro, active_sub, territory_step, out)
	if active_macro ~= "playing_stones" or active_sub == "territory" then
		return
	end
	for _, stone_event in ipairs(state.round_stone_effects or {}) do
		for _, stone_effect in ipairs(stone_event.effects or {}) do
			if def_matches(stone_effect, active_macro, active_sub, territory_step) then
				local resolved = effects_registry.stones.resolve(stone_effect)
				if resolved then
					local owner = stone_event.owner
					table.insert(out, {
						owner = owner,
						phase = resolved.sub or resolved.phase,
						sub = resolved.sub or sub_from_payload(resolved),
						macro = active_macro,
						priority = resolved.priority or 10,
						conditions = resolved.conditions,
						apply = function(current_state)
							resolved.apply(current_state, owner)
						end,
						meta = {
							source_owner = owner,
							source_object_type = "stone",
							source_def_id = stone_event.stone_type,
						},
					})
				end
			end
		end
	end
end

--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_board_stone_effects(state, active_macro, active_sub, territory_step, out)
	local owner_from_color = function(color)
		if color == 1 then
			return config.OWNER_BLACK
		end
		if color == 2 then
			return config.OWNER_WHITE
		end
		return nil
	end
	local n = #state.board
	for r = 1, n do
		for c = 1, n do
			local cell = state.board[r][c]
			if not board.is_empty(cell) then
				local generated = effects_registry.stones.resolve_board_stone(
					cell,
					r,
					c,
					state,
					active_macro,
					active_sub,
					territory_step
				)
				for _, e in ipairs(generated) do
					table.insert(out, e)
				end
				if active_sub == "points" and active_macro == "playing_stones" and not territory_step then
					local key = r .. ":" .. c
					local mods = state.board_stone_modifiers and state.board_stone_modifiers[key]
					local bonus = mods and mods.points_bonus or 0
					if bonus ~= 0 then
						local owner = owner_from_color(cell.color)
						if owner then
							table.insert(out, {
								owner = owner,
								phase = "points",
								sub = "points",
								macro = active_macro,
								priority = 25,
								conditions = nil,
								apply = function(current_state)
									current_state.scores.points[owner] = current_state.scores.points[owner] + bonus
								end,
								meta = {
									source_owner = owner,
									source_object_type = "board_modifier",
								},
							})
						end
					end
				end
			end
		end
	end
end

--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_timed_effects(state, active_macro, active_sub, territory_step, out)
	for _, active in ipairs(state.active_effects or {}) do
		local effect = active.effect
		local effect_def = effect and effect._effect_def
		if effect_def and def_matches(effect_def, active_macro, active_sub, territory_step) then
			table.insert(out, effect)
		elseif effect and effect.sub == active_sub and effect.macro == active_macro then
			table.insert(out, effect)
		end
	end
end

--- @param a table
--- @param b table
--- @return boolean
local function effect_priority(a, b)
	return a.priority < b.priority
end

--- @param state table
--- @param effect table
--- @return nil
local function add_effect_duration(state, effect)
	if effect.duration and effect.duration > 0 then
		state.active_effects[#state.active_effects + 1] = { effect = effect, remaining_turns = effect.duration }
	end
end

--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param effect table
--- @return nil
local function set_resolution_for_effect(state, active_macro, active_sub, effect)
	local resolution = queries.ensure_resolution(state)
	local meta = effect.meta or {}
	resolution.macro = active_macro
	resolution.sub = active_sub
	resolution.phase = active_sub
	resolution.territory_step = territory_step
	resolution.trigger = "phase"
	resolution.effect_owner = effect.owner ~= nil and effect.owner or meta.source_owner
	resolution.source_owner = meta.source_owner
	resolution.source_def_id = meta.source_def_id
	resolution.source_instance_id = meta.source_instance_id
	resolution.source_object_type = meta.source_object_type
	resolution.source_stance_index = meta.source_stance_index
	resolution.source_stance_slot_index = meta.source_stance_slot_index
	resolution.selected_target = meta.selected_target
end

--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @return table
function M.collect_effects(state, active_macro, active_sub, territory_step)
	local effects = {}
	append_stance_effects(state, active_macro, active_sub, territory_step, effects)
	append_card_effects(state, active_macro, active_sub, territory_step, effects)
	append_stone_round_effects(state, active_macro, active_sub, territory_step, effects)
	append_board_stone_effects(state, active_macro, active_sub, territory_step, effects)
	append_timed_effects(state, active_macro, active_sub, territory_step, effects)
	table.sort(effects, effect_priority)
	dbg.log_stack("collected effects", {
		macro = active_macro,
		sub = active_sub,
		territory_step = territory_step,
		effects = effects,
	})
	return effects
end

--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @return nil
function M.apply_sub_phase(state, active_macro, active_sub, territory_step)
	local conditions = require("objects.conditions")
	local effects = M.collect_effects(state, active_macro, active_sub, territory_step)
	queries.clear_resolution(state)
	for _, effect in ipairs(effects) do
		set_resolution_for_effect(state, active_macro, active_sub, effect)
		if conditions.eval_all(effect.conditions, state) then
			effect.apply(state)
			add_effect_duration(state, effect)
		end
	end
	queries.clear_resolution(state)
end

--- Back-compat for territory preview and tests.
--- @param state table
--- @param phase string legacy sub name
--- @return nil
function M.apply_phase(state, phase)
	local macro = state._resolve_macro or "playing_stones"
	if phase == "distance" then
		M.apply_sub_phase(state, macro, "territory", scoring_phases.TERRITORY_STEP_DISTANCE)
	elseif phase == "territory" then
		M.apply_sub_phase(state, macro, "territory", scoring_phases.TERRITORY_STEP_VALUE)
	else
		M.apply_sub_phase(state, macro, phase, nil)
	end
end

return M
