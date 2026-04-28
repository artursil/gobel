--- Playing card effect builders and resolution from `playing_cards.definitions`.
--- @module playing_cards.effects

local definitions = require("playing_cards.definitions")

local M = {}

--- @param card table
--- @param state table
--- @return string
local function owner_for_card(card, state)
	if card.owner == "A" or card.owner == "B" then
		return card.owner
	end
	if state.to_play == "white" then
		return "B"
	end
	return "A"
end

--- @param phase string
--- @param card table
--- @param owner string
--- @param value number
--- @param priority integer|nil
--- @return table
local function build_phase_effect(phase, card, owner, value, priority)
	return {
		phase = phase,
		priority = priority or 10,
		apply = function(state)
			print("[Effect Triggered]", card.type, phase)
			state.scores[phase][owner] = state.scores[phase][owner] + value
		end,
	}
end

--- @param card table
--- @param owner string
--- @param value number
--- @param priority integer|nil
--- @return table
function M.add_points(card, owner, value, priority)
	return build_phase_effect("points", card, owner, value, priority)
end

--- @param card table
--- @param owner string
--- @param value number
--- @param priority integer|nil
--- @return table
function M.add_mult(card, owner, value, priority)
	return build_phase_effect("mult", card, owner, value, priority)
end

--- @param card table
--- @param state table
--- @return table
function M.resolve(card, state)
	local owner = owner_for_card(card, state)
	local card_def = definitions[card.type]
	if not card_def or not card_def.effects then
		return {}
	end
	local out = {}
	for i = 1, #card_def.effects do
		local effect = card_def.effects[i]
		local effect_builder = M[effect.effect_name]
		if effect_builder then
			out[#out + 1] = effect_builder(card, owner, effect.value, effect.priority)
		end
	end
	return out
end

return M
