local Effects = require("effect_registry")

local M = {}

M.PHASES = { "pre", "territory", "points", "mult", "post" }

function M.ensure_state_extensions(state)
	state.stances = state.stances or {}
	state.modifiers = state.modifiers or {}
	state.last_played_stone = state.last_played_stone or nil
	state.scores = state.scores or {
		territory = { B = 0, W = 0 },
		points = { B = 0, W = 0 },
		mult = { B = 1, W = 1 },
	}
end

function M.collect_effects(state, phase)
	local effects = {}
	for i, stance in ipairs(state.stances or {}) do
		stance.index = i
		local generated = Effects.stances.resolve(stance, state)
		for _, e in ipairs(generated) do
			if e.phase == phase then
				table.insert(effects, e)
			end
		end
	end
	for _, card in ipairs(state.modifiers or {}) do
		local generated = Effects.cards.resolve(card, state)
		for _, e in ipairs(generated) do
			if e.phase == phase then
				table.insert(effects, e)
			end
		end
	end
	table.sort(effects, function(a, b)
		return a.priority < b.priority
	end)
	return effects
end

function M.apply_phase(state, phase)
	local effects = M.collect_effects(state, phase)
	for _, effect in ipairs(effects) do
		effect.apply(state)
	end
end

function M.run_scoring_phases(state, calculate_territory, calculate_final_score)
	calculate_territory(state)
	for _, phase in ipairs(M.PHASES) do
		M.apply_phase(state, phase)
	end
	calculate_final_score(state)
end

return M
