local board = require("board")
local effects_registry = require("effect_registry")

local M = {}

local function phase_from_payload(payload)
	if payload.type == "ADD_POINTS" then
		return "points"
	end
	return "mult"
end

local function append_pose_effects(state, phase, out)
	for i, pose in ipairs(state.poses or {}) do
		pose.index = i
		local generated = effects_registry.poses.resolve(pose, state)
		for _, e in ipairs(generated) do
			if e.phase == phase then
				table.insert(out, e)
			end
		end
	end
end

local function append_card_effects(state, phase, out)
	for _, card in ipairs(state.modifiers or {}) do
		local generated = effects_registry.cards.resolve(card, state)
		for _, e in ipairs(generated) do
			if e.phase == phase then
				table.insert(out, e)
			end
		end
	end
end

local function append_stone_round_effects(state, phase, out)
	for _, stone_event in ipairs(state.round_stone_effects or {}) do
		for _, stone_effect in ipairs(stone_event.effects or {}) do
			local resolved = effects_registry.stones.resolve(stone_effect)
			if resolved then
				local effect_phase = phase_from_payload(resolved)
				if effect_phase == phase then
					local owner = stone_event.owner
					local source_name = stone_event.stone_type or "stone"
					table.insert(out, {
						phase = effect_phase,
						priority = resolved.priority or 10,
						apply = function(current_state)
							print("[Effect Triggered]", source_name, effect_phase)
							if effect_phase == "points" then
								current_state.scores.points[owner] = current_state.scores.points[owner] + resolved.value
							else
								current_state.scores.mult[owner] = current_state.scores.mult[owner] + resolved.value
							end
						end,
					})
				end
			end
		end
	end
end

local function append_board_stone_effects(state, phase, out)
	local n = #state.board
	for r = 1, n do
		for c = 1, n do
			local cell = state.board[r][c]
			if not board.is_empty(cell) then
				local generated = effects_registry.stones.resolve_board_stone(cell, state)
				for _, e in ipairs(generated) do
					if e.phase == phase then
						table.insert(out, e)
					end
				end
			end
		end
	end
end

local function append_timed_effects(state, phase, out)
	for _, active in ipairs(state.active_effects or {}) do
		local effect = active.effect
		if effect and effect.phase == phase then
			table.insert(out, effect)
		end
	end
end

function M.collect_effects(state, phase)
	local effects = {}
	append_pose_effects(state, phase, effects)
	append_card_effects(state, phase, effects)
	append_stone_round_effects(state, phase, effects)
	append_board_stone_effects(state, phase, effects)
	append_timed_effects(state, phase, effects)
	table.sort(effects, function(a, b)
		return a.priority < b.priority
	end)
	return effects
end

function M.apply_phase(state, phase)
	local effects = M.collect_effects(state, phase)
	for _, effect in ipairs(effects) do
		effect.apply(state)
		if effect.duration and effect.duration > 0 then
			state.active_effects[#state.active_effects + 1] = { effect = effect, remaining_turns = effect.duration }
		end
	end
end

return M
