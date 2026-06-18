--- Shared stone combat helpers for card targeting: damage, heal, removal enqueue.
--- @module objects.effects_conditions.helpers.shared.stone_combat

local config = require("config")
local stone_solidity = require("objects.stone_solidity")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")

local M = {}

--- Side string for removal metadata from effect owner token.
--- @param owner string
--- @return string
function M.capturer_side(owner)
	if owner == config.OWNER_WHITE then
		return "white"
	end
	return "black"
end

--- Intrinsic solidity excluding defence network bonus.
--- @param cell table
--- @return integer intrinsic
--- @return integer current
--- @return integer defence_bonus
function M.intrinsic_solidity(cell)
	local current = cell.solidity or stone_solidity.stone_max_solidity(cell.kind)
	local defence_bonus = cell._defence_solidity_bonus or 0
	return current - defence_bonus, current, defence_bonus
end

--- Reduce intrinsic solidity; at zero set cell solidity to 0 and enqueue removal.
--- @param state table
--- @param owner string
--- @param row integer
--- @param col integer
--- @param cell table
--- @param amount integer
--- @param reason string|nil
--- @return boolean lethal when removal was enqueued
function M.apply_damage_to_cell(state, owner, row, col, cell, amount, reason)
	local intrinsic, _, defence_bonus = M.intrinsic_solidity(cell)
	local next_intrinsic = math.max(0, intrinsic - amount)
	if next_intrinsic <= 0 then
		cell.solidity = 0
		pending_removals.enqueue(state, {
			row = row,
			col = col,
			capturer = M.capturer_side(owner),
			reason = reason or "card_damage",
		})
		return true
	end
	cell.solidity = next_intrinsic + defence_bonus
	return false
end

--- Heal cell solidity up to kind maximum.
--- @param cell table
--- @param amount integer
--- @return nil
function M.apply_heal_to_cell(cell, amount)
	local current = cell.solidity or stone_solidity.stone_max_solidity(cell.kind)
	local max_s = stone_solidity.stone_max_solidity(cell.kind)
	cell.solidity = math.min(max_s, current + amount)
end

--- Enqueue effect-driven stone removal without clearing the board cell.
--- @param state table
--- @param owner string
--- @param row integer
--- @param col integer
--- @param reason string
--- @return nil
function M.enqueue_removal(state, owner, row, col, reason)
	pending_removals.enqueue(state, {
		row = row,
		col = col,
		capturer = M.capturer_side(owner),
		reason = reason,
	})
end

return M
