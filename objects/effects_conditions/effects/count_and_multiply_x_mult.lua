--- Multiply x_mult once per steel card currently in the owner's hand.
--- @module objects.effects_conditions.effects.count_and_multiply_x_mult

local config = require("config")
local animations = require("objects.animations")
local scheduling = require("objects.effects_conditions.scheduling")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value
	return {
		type = "COUNT_AND_MULTIPLY_X_MULT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.mult,
		priority = effect.priority or 15,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local match_state = require("match_state")
			local player_state = match_state.player_for_color(state, owner == config.OWNER_BLACK and "black" or "white")
			if not player_state then
				return
			end
			local hand_ids = player_state.cards.hand and player_state.cards.hand.ids
			if not hand_ids then
				return
			end
			local content = require("content")
			local steel_card_count = 0
			local steel_hand_indices = {}
			for hand_index, card_id in ipairs(hand_ids) do
				if card_id then
					local card_def = content.get_card(card_id)
					if card_def and card_def.tags then
						for _, tag in ipairs(card_def.tags) do
							if tag == "steel" then
								steel_card_count = steel_card_count + 1
								steel_hand_indices[#steel_hand_indices + 1] = hand_index
								break
							end
						end
					end
				end
			end
			if steel_card_count <= 0 then
				return
			end
			local multiplier_factor = 1 + value
			local x_mult_steps = {}
			for _ = 1, steel_card_count do
				state.scores.x_mult[owner] = state.scores.x_mult[owner] * multiplier_factor
				x_mult_steps[#x_mult_steps + 1] = state.scores.x_mult[owner]
			end
			animations.add_animation("steel_sync_mult")(state, {
				owner = owner,
				steel_hand_indices = steel_hand_indices,
				factor = multiplier_factor,
				x_mult_steps = x_mult_steps,
			})
		end,
	}
end

return M
