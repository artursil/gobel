--- Coordinates stance, card, stone, and timed effects by action/phase; sorts by priority; applies.
--- @module resolver.effect_manager

local board = require("board")
local config = require("config")
local effects_registry = require("effect_registry")
local dbg = require("debugger")
local queries = require("single_game.resolver.state_queries")
local scoring_phases = require("single_game.resolver.scoring_phases")
local stance_order = require("single_game.resolver.stance_order")
local shared_stones_effects = require("objects.definitions.shared_stones_effects")
local objects_effects = require("objects.effects")
local effect_enums = require("objects.effect_enums")
local effect_schedule = require("objects.effect_schedule")

local M = {}

--- @param payload table
--- @return string|nil phase
local function phase_from_payload(payload)
	if payload.phase then
		return effect_enums.sub_to_phase(payload.phase)
	end
	if payload.sub then
		return effect_enums.sub_to_phase(payload.sub)
	end
	return nil
end

--- @param active_action string canonical action or legacy resolve macro
--- @return string action
local function normalize_active_action(active_action)
	return effect_enums.resolve_macro_to_action(active_action)
end

--- @param effect_def table
--- @param active_action string
--- @param active_phase string
--- @param territory_step string|nil
--- @return boolean
local function def_matches(effect_def, active_action, active_phase, territory_step)
	return scoring_phases.matches(effect_def, active_action, active_phase, territory_step)
end

--- @param state table
--- @param active_action string
--- @param active_phase string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_stance_effects(state, active_action, active_phase, territory_step, out)
	local action = normalize_active_action(active_action)
	local rows = stance_order.flatten_stances_for_resolve(state)
	for _, stance in ipairs(rows) do
		local i = stance.index
		local generated = effects_registry.stances.resolve(stance, state)
		for _, e in ipairs(generated) do
			local effect_def = e._effect_def
			if effect_def and def_matches(effect_def, action, active_phase, territory_step) then
				e.meta = e.meta or {}
				e.meta.source_owner = stance.owner
				e.meta.source_object_type = "stance"
				e.meta.source_stance_index = i
				e.meta.source_stance_slot_index = stance.slot_index
				e.meta.source_instance_id = stance.instance and stance.instance.instance_id or nil
				e.meta.source_def_id = stance.type
				table.insert(out, e)
			elseif not effect_def and phase_from_payload(e) == active_phase
				and (
					e.action and normalize_active_action(e.action) == action
					or e.macro and normalize_active_action(e.macro) == action
					or (not e.action and not e.macro and action == effect_enums.ACTION.on_play)
				) then
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
--- @param active_action string
--- @param active_phase string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_card_effects(state, active_action, active_phase, territory_step, out)
	local action = normalize_active_action(active_action)
	if action ~= effect_enums.ACTION.on_card then
		return
	end
	for _, card in ipairs(state.just_played or {}) do
		local generated = effects_registry.cards.resolve(card, state)
		for _, e in ipairs(generated) do
			local effect_def = e._effect_def
			if effect_def and def_matches(effect_def, action, active_phase, territory_step) then
				e.meta = e.meta or {}
				e.meta.source_owner = card.owner
				e.meta.source_object_type = "card"
				e.meta.source_def_id = card.type
				e.meta.selected_target = card.selected_target
				e.meta.selected_targets = card.selected_targets
				table.insert(out, e)
			elseif not effect_def and phase_from_payload(e) == active_phase
				and (
					(e.action and normalize_active_action(e.action) == action)
					or (e.macro and normalize_active_action(e.macro) == action)
					or action == effect_enums.ACTION.on_card
				) then
				e.meta = e.meta or {}
				e.meta.source_owner = card.owner
				e.meta.source_object_type = "card"
				e.meta.source_def_id = card.type
				e.meta.selected_target = card.selected_target
				e.meta.selected_targets = card.selected_targets
				table.insert(out, e)
			end
		end
	end
end

--- @param state table
--- @param active_action string
--- @param active_phase string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_stone_round_effects(state, active_action, active_phase, territory_step, out)
	local action = normalize_active_action(active_action)
	if action ~= effect_enums.ACTION.on_play or active_phase == effect_enums.PHASE.territory then
		return
	end
	local events = state.round_stone_effects or {}
	local stone_event = events[#events]
	if not stone_event then
		return
	end
	local resolve_macro = effect_schedule.action_to_resolve_macro(action)
	for _, stone_effect in ipairs(stone_event.effects or {}) do
		if def_matches(stone_effect, action, active_phase, territory_step) then
			local resolved = effects_registry.stones.resolve(stone_effect)
			if resolved then
				local owner = stone_event.owner
				local row, col = stone_event.row, stone_event.col
				local phase = resolved.phase or phase_from_payload(resolved)
				table.insert(out, {
					owner = owner,
					action = action,
					phase = phase,
					sub = phase,
					macro = resolve_macro,
					priority = resolved.priority or 10,
					conditions = resolved.conditions,
					apply = function(current_state)
						if resolved.apply then
							resolved.apply(current_state, owner, row, col)
						end
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

--- @param state table
--- @param active_action string
--- @param active_phase string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_board_stone_effects(state, active_action, active_phase, territory_step, out)
	local action = normalize_active_action(active_action)
	local resolve_macro = effect_schedule.action_to_resolve_macro(action)
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
					action,
					active_phase,
					territory_step
				)
				for _, e in ipairs(generated) do
					table.insert(out, e)
				end
				if active_phase == effect_enums.PHASE.points and action == effect_enums.ACTION.on_play and not territory_step then
					local key = r .. ":" .. c
					local mods = state.board_stone_modifiers and state.board_stone_modifiers[key]
					local bonus = mods and mods.points_bonus or 0
					if bonus ~= 0 then
						local owner = owner_from_color(cell.color)
						if owner then
							table.insert(out, {
								owner = owner,
								action = action,
								phase = effect_enums.PHASE.points,
								sub = effect_enums.PHASE.points,
								macro = resolve_macro,
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
--- @param active_action string
--- @param active_phase string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_pattern_board_effects(state, active_action, active_phase, territory_step, out)
	if active_phase ~= effect_enums.PHASE.mult then
		return
	end
	local action = normalize_active_action(active_action)
	local resolve_macro = effect_schedule.action_to_resolve_macro(action)
	local to_play = state.to_play
	if not to_play or to_play == "none" then
		return
	end
	local owner = to_play == "white" and config.OWNER_WHITE or config.OWNER_BLACK
	local pattern_defs = {
		shared_stones_effects.pattern_x_mult,
		shared_stones_effects.pattern_plus_mult,
	}
	for i = 1, #pattern_defs do
		local effect_def = pattern_defs[i]
		if def_matches(effect_def, action, active_phase, territory_step) then
			local resolved = objects_effects.resolve(effect_def)
			if resolved and resolved.apply then
				table.insert(out, {
					owner = owner,
					action = action,
					phase = effect_enums.PHASE.mult,
					sub = effect_enums.PHASE.mult,
					macro = resolve_macro,
					priority = resolved.priority or 12,
					conditions = resolved.conditions,
					apply = function(current_state)
						resolved.apply(current_state, owner)
					end,
					meta = {
						source_owner = owner,
						source_object_type = "pattern",
					},
				})
			end
		end
	end
end

--- @param state table
--- @param active_action string
--- @param active_phase string
--- @param territory_step string|nil
--- @param out table
--- @return nil
local function append_timed_effects(state, active_action, active_phase, territory_step, out)
	local action = normalize_active_action(active_action)
	for _, active in ipairs(state.active_effects or {}) do
		local effect = active.effect
		local effect_def = effect and effect._effect_def
		if effect_def and def_matches(effect_def, action, active_phase, territory_step) then
			table.insert(out, effect)
		elseif effect and phase_from_payload(effect) == active_phase
			and (
				(effect.action and normalize_active_action(effect.action) == action)
				or (effect.macro and normalize_active_action(effect.macro) == action)
			) then
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
--- @param active_action string
--- @param active_phase string
--- @param effect table
--- @return nil
local function set_resolution_for_effect(state, active_action, active_phase, territory_step, effect)
	local action = normalize_active_action(active_action)
	local resolve_macro = effect_schedule.action_to_resolve_macro(action)
	local resolution = queries.ensure_resolution(state)
	local meta = effect.meta or {}
	resolution.action = action
	resolution.macro = resolve_macro
	resolution.sub = active_phase
	resolution.phase = active_phase
	resolution.territory_step = territory_step
	resolution.trigger = "phase"
	resolution.effect_owner = effect.owner ~= nil and effect.owner or meta.source_owner
	resolution.source_owner = meta.source_owner
	resolution.source_def_id = meta.source_def_id
	resolution.source_instance_id = meta.source_instance_id
	resolution.source_object_type = meta.source_object_type
	resolution.source_stance_index = meta.source_stance_index
	resolution.source_stance_slot_index = meta.source_stance_slot_index
	resolution.selected_target = meta.selected_target or (meta.selected_targets and meta.selected_targets[1]) or nil
	resolution.selected_targets = meta.selected_targets
end

--- @param state table
--- @param active_action string canonical action or legacy resolve macro
--- @param active_phase string
--- @param territory_step string|nil
--- @return table
function M.collect_effects(state, active_action, active_phase, territory_step)
	local action = normalize_active_action(active_action)
	local effects = {}
	append_stance_effects(state, action, active_phase, territory_step, effects)
	append_card_effects(state, action, active_phase, territory_step, effects)
	append_stone_round_effects(state, action, active_phase, territory_step, effects)
	append_board_stone_effects(state, action, active_phase, territory_step, effects)
	append_pattern_board_effects(state, action, active_phase, territory_step, effects)
	append_timed_effects(state, action, active_phase, territory_step, effects)
	table.sort(effects, effect_priority)
	dbg.log_stack("collected effects", {
		action = action,
		macro = effect_schedule.action_to_resolve_macro(action),
		phase = active_phase,
		sub = active_phase,
		territory_step = territory_step,
		effects = effects,
	})
	return effects
end

--- @param state table
--- @param active_action string canonical action or legacy resolve macro
--- @param active_phase string
--- @param territory_step string|nil
--- @return nil
function M.apply_phase_pass(state, active_action, active_phase, territory_step)
	local action = normalize_active_action(active_action)
	local conditions = require("objects.conditions")
	local effects = M.collect_effects(state, action, active_phase, territory_step)
	queries.clear_resolution(state)
	for _, effect in ipairs(effects) do
		set_resolution_for_effect(state, action, active_phase, territory_step, effect)
		if conditions.eval_all(effect.conditions, state) then
			effect.apply(state)
			add_effect_duration(state, effect)
		end
	end
	queries.clear_resolution(state)
end

--- Legacy alias for ``apply_phase_pass`` (accepts legacy resolve macro as first scheduling arg).
--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @return nil
function M.apply_sub_phase(state, active_macro, active_sub, territory_step)
	M.apply_phase_pass(state, active_macro, active_sub, territory_step)
end

--- Back-compat for territory preview and tests.
--- @param state table
--- @param phase string legacy phase or sub name
--- @return nil
function M.apply_phase(state, phase)
	local action = state._resolve_action or effect_enums.resolve_macro_to_action(state._resolve_macro) or effect_enums.ACTION.on_play
	if phase == "distance" then
		M.apply_phase_pass(state, action, effect_enums.PHASE.territory, scoring_phases.TERRITORY_STEP_DISTANCE)
	elseif phase == "territory" then
		M.apply_phase_pass(state, action, effect_enums.PHASE.territory, scoring_phases.TERRITORY_STEP_VALUE)
	else
		M.apply_phase_pass(state, action, phase, nil)
	end
end

return M
