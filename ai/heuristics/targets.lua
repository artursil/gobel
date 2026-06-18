--- Board target enumeration and scoring for targeted cards.
--- @module ai.heuristics.targets

local board = require("board")
local config = require("config")
local content = require("content")
local deck = require("deck")
local energy = require("energy")

local M = {}

--- @param view table
--- @param hand_index integer
--- @return table|nil card_def
local function card_def_for_hand(view, hand_index)
	local cards_state = view:player().cards
	if not deck.can_play_from_hand(cards_state, hand_index) then
		return nil
	end
	return content.get_card(cards_state.hand.ids[hand_index])
end

--- @param view table
--- @param rule string|nil
--- @return table[] { row, col }
function M.legal_cells(view, rule)
	local out = {}
	local b = view:board()
	local my_color = view:stone_color()
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local cell = b[r] and b[r][c]
			if cell and not board.is_empty(cell) then
				if rule == "enemy" and cell.color ~= my_color then
					out[#out + 1] = { row = r, col = c }
				elseif rule == "friendly" and cell.color == my_color then
					out[#out + 1] = { row = r, col = c }
				end
			end
		end
	end
	return out
end

--- @param view table
--- @param hand_index integer
--- @return table[] { row, col }
function M.legal_for_card(view, hand_index)
	local card_def = card_def_for_hand(view, hand_index)
	if not card_def or not card_def.targeting or card_def.targeting.kind ~= "board_stone" then
		return {}
	end
	if not energy.can_spend(view:player(), card_def.energy_cost or 0) then
		return {}
	end
	return M.legal_cells(view, card_def.targeting.rule)
end

--- @param view table
--- @param hand_index integer
--- @param row integer
--- @param col integer
--- @return number
function M.score(view, hand_index, row, col)
	local card_def = card_def_for_hand(view, hand_index)
	if not card_def or not card_def.targeting or card_def.targeting.kind ~= "board_stone" then
		return 0
	end
	local rule = card_def.targeting.rule
	local legal = M.legal_cells(view, rule)
	for i = 1, #legal do
		if legal[i].row == row and legal[i].col == col then
			if rule == "enemy" then
				return 2
			end
			if rule == "friendly" then
				return 1
			end
			return 0
		end
	end
	return 0
end

return M
