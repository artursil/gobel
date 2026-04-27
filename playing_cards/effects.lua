local definitions = require("playing_cards.definitions")

local M = {}

local function owner_for_card(card, state)
	if card.owner == "A" or card.owner == "B" then
		return card.owner
	end
	if state.to_play == "white" then
		return "B"
	end
	return "A"
end

function M.add_points(card, owner, value, priority)
	return {
		phase = "points",
		priority = priority or 10,
		apply = function(state)
			print("[Effect Triggered]", card.type, "points")
			state.scores.points[owner] = state.scores.points[owner] + value
		end,
	}
end

function M.add_mult(card, owner, value, priority)
	return {
		phase = "mult",
		priority = priority or 10,
		apply = function(state)
			print("[Effect Triggered]", card.type, "mult")
			state.scores.mult[owner] = state.scores.mult[owner] + value
		end,
	}
end

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
