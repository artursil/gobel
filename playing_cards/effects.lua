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

local function phase_for_effect(effect)
	if effect.type == "ADD_POINTS" then
		return "points"
	end
	return "mult"
end

local function build_generator(card_id)
	return function(card, state)
		local owner = owner_for_card(card, state)
		local card_def = definitions[card_id]
		if not card_def or not card_def.effects then
			return {}
		end
		local out = {}
		for i = 1, #card_def.effects do
			local effect = card_def.effects[i]
			local phase = phase_for_effect(effect)
			out[#out + 1] = {
				phase = phase,
				priority = effect.priority or 10,
				apply = function(current_state)
					print("[Effect Triggered]", card.type, phase)
					if phase == "points" then
						current_state.scores.points[owner] = current_state.scores.points[owner] + effect.value
					else
						current_state.scores.mult[owner] = current_state.scores.mult[owner] + effect.value
					end
				end,
			}
		end
		return out
	end
end

for card_id, _ in pairs(definitions) do
	M[card_id] = build_generator(card_id)
end

return M
