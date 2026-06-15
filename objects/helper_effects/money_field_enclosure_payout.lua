--- Money payout when the placement cell is owner-enclosed on the post-placement board.
--- @module objects.helper_effects.money_field_enclosure_payout

local config = require("config")

local M = {}

--- @param state table
--- @param owner string
--- @param row integer
--- @param col integer
--- @return nil
function M.apply(state, owner, row, col)
	local enclosure_placement = require("single_game.resolver.enclosure_placement")
	local amount = enclosure_placement.placement_money_payout(state.board, row, col, owner)
	if amount <= 0 then
		return
	end
	local side = owner == config.OWNER_BLACK and "black" or "white"
	local player = require("match_state").player_for_color(state, side)
	player.resources.money = (player.resources.money or 0) + amount
end

return M
