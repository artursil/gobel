local M = {}
local array_utils = require("array_utils")

function M.new(deck_ids, hand_target_size, rng_next_int)
	local ids = array_utils.clone(deck_ids)
	array_utils.shuffle_in_place(ids, rng_next_int)
	return {
		deck = { ids = ids },
		hand = { ids = {} },
		discard = { ids = {} },
		hand_target_size = hand_target_size,
	}
end

function M.reshuffle_discard_into_deck(cards_state, rng_next_int)
	if #cards_state.discard.ids == 0 then
		return false
	end
	array_utils.append_all(cards_state.deck.ids, cards_state.discard.ids)
	cards_state.discard.ids = {}
	array_utils.shuffle_in_place(cards_state.deck.ids, rng_next_int)
	return true
end

function M.draw_one(cards_state, rng_next_int)
	if #cards_state.deck.ids == 0 then
		local reshuffled = M.reshuffle_discard_into_deck(cards_state, rng_next_int)
		if not reshuffled then
			return nil
		end
	end
	local idx = #cards_state.deck.ids
	local card_id = cards_state.deck.ids[idx]
	cards_state.deck.ids[idx] = nil
	cards_state.hand.ids[#cards_state.hand.ids + 1] = card_id
	return card_id
end

function M.draw_to_hand_target(cards_state, rng_next_int)
	while #cards_state.hand.ids < cards_state.hand_target_size do
		local drawn = M.draw_one(cards_state, rng_next_int)
		if not drawn then
			break
		end
	end
end

function M.can_play_from_hand(cards_state, hand_index)
	return hand_index >= 1 and hand_index <= #cards_state.hand.ids
end

function M.play_from_hand(cards_state, hand_index)
	if not M.can_play_from_hand(cards_state, hand_index) then
		return nil
	end
	local card_id = table.remove(cards_state.hand.ids, hand_index)
	cards_state.discard.ids[#cards_state.discard.ids + 1] = card_id
	return card_id
end

return M
