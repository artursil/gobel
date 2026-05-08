--- Coordinates stance, card, stone, and timed effects by phase; sorts by priority; applies and registers durations.
--- @module resolver.effect_manager

local board = require("board")
local effects_registry = require("effect_registry")
local dbg = require("debugger")

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
				e.context = {
					stance_owner = stance.owner,
					instance = stance.instance,
					stance_entry = stance,
				}
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
	for _, card in ipairs(state.modifiers or {}) do
		local generated = effects_registry.cards.resolve(card, state)
		for _, e in ipairs(generated) do
			if e.phase == phase then
				e.context = e.context or {}
				e.context.selected_target = card.selected_target
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
	local content = require("content")
	for _, stone_event in ipairs(state.round_stone_effects or {}) do
		local stone_def = content.get_stone(stone_event.stone_type)
		for _, stone_effect in ipairs(stone_event.effects or {}) do
			local resolved = effects_registry.stones.resolve(stone_effect)
			if resolved then
				local effect_phase = phase_from_payload(resolved)
				if effect_phase == phase then
					local owner = stone_event.owner
					local stone_context = {
						last_placed_stone = {
							tags = (stone_def and stone_def.tags) or {},
							stone_id = stone_event.stone_type,
						},
					}
					table.insert(out, {
						phase = effect_phase,
						priority = resolved.priority or 10,
						conditions = resolved.conditions,
						apply = function(current_state, _, ctx)
							resolved.apply(current_state, owner, stone_context)
						end,
						context = stone_context,
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
			return "A"
		end
		if color == 2 then
			return "B"
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
								phase = "points",
								priority = 25,
								conditions = nil,
								apply = function(current_state)
									current_state.scores.points[owner] = current_state.scores.points[owner] + bonus
								end,
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
--- @param context table: Optional context to pass to effects
--- @return nil
function M.apply_phase(state, phase, context)
	local conditions = require("objects.conditions")
	local effects = M.collect_effects(state, phase)
	-- dbg.log_stack("effects", {context = context})
	context = context or { state = state }
	for _, effect in ipairs(effects) do
		local eval_context = { state = state, phase = phase }
		if context.current_turn_owner then
			eval_context.current_turn_owner = context.current_turn_owner
		end
		if context.last_placed_stone then
			eval_context.last_placed_stone = context.last_placed_stone
		end
		if effect.context then
			if effect.context.selected_target then -- TODO: What does it even do?
				eval_context.selected_target = effect.context.selected_target
			end
			if effect.context.stance_owner then
				eval_context.stance_owner = effect.context.stance_owner
			end
			if effect.context.instance then
				eval_context.instance = effect.context.instance
			end
			if effect.context.stance_entry then
				eval_context.stance_entry = effect.context.stance_entry
			end
		end
		eval_context.effect_owner = effect.owner
		if conditions.eval_all(effect.conditions, eval_context) then
			effect.apply(state, nil, eval_context)
			add_effect_duration(state, effect)
		end
	end
end

return M
