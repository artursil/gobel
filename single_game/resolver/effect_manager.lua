--- Coordinates stance, card, stone, and timed effects by phase; sorts by priority; applies and registers durations.
---
--- Transient `state.resolution` (see `state_queries.ensure_resolution`) is set per effect before conditions run:
--- - **effect_owner**: who receives score/application for this wrapped effect (`effect.owner`), same convention as registry wrap.
---   Stone round snippets set `effect.owner`; if absent, falls back to `meta.source_owner` so `queries.effect_owner` stays consistent.
--- - **source_owner** / **source_def_id** / **source_instance_id**: originating object (stance lane, card from `state.just_played`, copied target, etc.).
--- @module resolver.effect_manager

local board = require("board")
local config = require("config")
local effects_registry = require("effect_registry")
local dbg = require("debugger")
local queries = require("single_game.resolver.state_queries")

local M = {}

--- @param payload table
--- @return string  `"points"` or `"mult"`
local function phase_from_payload(payload)
	if payload.phase then
		return payload.phase
	end
	if payload.type == "ADD_POINTS" then
		return "points"
	end
	return "mult"
end

--- @param state table
--- @param phase string
--- @param out table
--- @return nil
local function append_stance_effects(state, phase, out)
	for i, stance in ipairs(state.stances or {}) do
		stance.index = i
		local generated = effects_registry.stances.resolve(stance, state)
		for _, e in ipairs(generated) do
			if e.phase == phase then
				e.meta = e.meta or {}
				e.meta.source_owner = stance.owner
				e.meta.source_object_type = "stance"
				e.meta.source_stance_index = i
				e.meta.source_instance_id = stance.instance and stance.instance.instance_id or nil
				e.meta.source_def_id = stance.type
				table.insert(out, e)
			end
		end
	end
end

--- @param state table
--- @param phase string
--- @param out table
--- @return nil
local function append_card_effects(state, phase, out)
	for _, card in ipairs(state.just_played or {}) do
		local generated = effects_registry.cards.resolve(card, state)
		for _, e in ipairs(generated) do
			if e.phase == phase then
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

--- Resolves `round_stone_effects` from the registry and appends point/mult effects.
--- @param state table
--- @param phase string
--- @param out table
--- @return nil
local function append_stone_round_effects(state, phase, out)
	for _, stone_event in ipairs(state.round_stone_effects or {}) do
		for _, stone_effect in ipairs(stone_event.effects or {}) do
			local resolved = effects_registry.stones.resolve(stone_effect)
			if resolved then
				local effect_phase = phase_from_payload(resolved)
				if effect_phase == phase then
					local owner = stone_event.owner
					table.insert(out, {
						owner = owner,
						phase = effect_phase,
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
--- @param phase string
--- @param out table
--- @return nil
local function append_board_stone_effects(state, phase, out)
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
				local generated = effects_registry.stones.resolve_board_stone(cell, r, c, state)
				for _, e in ipairs(generated) do
					if e.phase == phase then
						table.insert(out, e)
					end
				end
				if phase == "points" then
					local key = r .. ":" .. c
					local mods = state.board_stone_modifiers and state.board_stone_modifiers[key]
					local bonus = mods and mods.points_bonus or 0
					if bonus ~= 0 then
						local owner = owner_from_color(cell.color)
						if owner then
							table.insert(out, {
								owner = owner,
								phase = "points",
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
--- @param phase string
--- @param out table
--- @return nil
local function append_timed_effects(state, phase, out)
	for _, active in ipairs(state.active_effects or {}) do
		local effect = active.effect
		if effect and effect.phase == phase then
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

--- Applies metadata of current effect into state.resolution.
--- @param state table
--- @param phase string
--- @param effect table
--- @return nil
local function set_resolution_for_effect(state, phase, effect)
	local resolution = queries.ensure_resolution(state)
	local meta = effect.meta or {}
	resolution.phase = phase
	resolution.trigger = "phase"
	resolution.effect_owner = effect.owner ~= nil and effect.owner or meta.source_owner
	resolution.source_owner = meta.source_owner
	resolution.source_def_id = meta.source_def_id
	resolution.source_instance_id = meta.source_instance_id
	resolution.source_object_type = meta.source_object_type
	resolution.source_stance_index = meta.source_stance_index
	resolution.selected_target = meta.selected_target
end

--- Gathers and sorts all effects for one phase.
--- @param state table
--- @param phase string
--- @return table
function M.collect_effects(state, phase)
	local effects = {}
	append_stance_effects(state, phase, effects)
	append_card_effects(state, phase, effects)
	append_stone_round_effects(state, phase, effects)
	append_board_stone_effects(state, phase, effects)
	append_timed_effects(state, phase, effects)
	table.sort(effects, effect_priority)
	dbg.log_stack("collected effects", {phase = phase, effects = effects})
	return effects
end

--- Runs `apply` on every effect in order; registers effects with `duration` into `active_effects`.
--- Evaluates conditions before applying each effect.
--- @param state table
--- @param phase string
--- @return nil
function M.apply_phase(state, phase)
	local conditions = require("objects.conditions")
	local effects = M.collect_effects(state, phase)
	queries.clear_resolution(state)
	for _, effect in ipairs(effects) do
		set_resolution_for_effect(state, phase, effect)
		if conditions.eval_all(effect.conditions, state) then
			effect.apply(state)
			add_effect_duration(state, effect)
		end
	end
	queries.clear_resolution(state)
end

return M
