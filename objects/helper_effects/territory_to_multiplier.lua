--- Territory-to-multiplier snapshot and end-of-turn payout helpers.
--- @module objects.helper_effects.territory_to_multiplier

local config = require("config")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_helpers")

local M = {}

--- @return table
local function territory_module()
	return require("single_game.resolver.territory")
end

--- @param row integer
--- @param col integer
--- @return string
function M.stone_cell_key(row, col)
	return row .. ":" .. col
end

--- @param territory_count integer
--- @param divisor integer
--- @param cap integer
--- @return integer
function M.payout_for_territory_count(territory_count, divisor, cap)
	if divisor <= 0 or territory_count <= 0 then
		return 0
	end
	return math.min(cap, math.floor(territory_count / divisor))
end

--- @param territory_grid table
--- @param territory_value table|nil
--- @param owner "B"|"W"
--- @return integer
local function total_for_owner_on_grid(territory_grid, territory_value, owner)
	local territory = territory_module()
	local color = owner == config.OWNER_WHITE and config.STONE_WHITE or config.STONE_BLACK
	return territory.weighted_territory_points(territory_grid, color, territory_value or {})
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return "B"|"W"|nil owner
--- @return integer recipient_territory
function M.recipient_and_total(state, row, col)
	local territory = territory_module()
	local key = M.stone_cell_key(row, col)
	local snap = state.territory_stone_snapshots and state.territory_stone_snapshots[key]
	if snap and snap.placed_turn == (state.turn_number or 1) then
		if snap.owner == config.OWNER_BLACK then
			return snap.owner, snap.black_total
		end
		if snap.owner == config.OWNER_WHITE then
			return snap.owner, snap.white_total
		end
		return nil, 0
	end
	local owner = territory.hypothetical_empty_owner(state, row, col)
	if not owner then
		return nil, 0
	end
	local total = territory.total_territory_for_owner(state, owner)
	return owner, total
end

--- @param state table
--- @param row integer|nil
--- @param col integer|nil
--- @return nil
function M.capture_snapshot(state, row, col)
	if row == nil or col == nil then
		row, col = helpers.placement_coords(state)
	end
	if row == nil or col == nil then
		return
	end
	local territory = territory_module()
	if not state.territory then
		return
	end
	local key = M.stone_cell_key(row, col)
	local pre = state.territory_placement_snapshots and state.territory_placement_snapshots[key]
	local owner
	local black_total
	local white_total
	if pre and pre.territory then
		owner = territory.owner_at_territory_cell(pre.territory, row, col)
		black_total = total_for_owner_on_grid(pre.territory, pre.territory_value, config.OWNER_BLACK)
		white_total = total_for_owner_on_grid(pre.territory, pre.territory_value, config.OWNER_WHITE)
	else
		owner = territory.hypothetical_empty_owner(state, row, col)
		black_total = territory.total_territory_for_owner(state, config.OWNER_BLACK)
		white_total = territory.total_territory_for_owner(state, config.OWNER_WHITE)
	end
	state.territory_stone_snapshots = state.territory_stone_snapshots or {}
	state.territory_stone_snapshots[key] = {
		owner = owner,
		black_total = black_total,
		white_total = white_total,
		placed_turn = state.turn_number or 1,
	}
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.apply_end_of_turn(state, row, col)
	local recipient, recipient_territory = M.recipient_and_total(state, row, col)
	if not recipient then
		return
	end
	local payout = M.payout_for_territory_count(
		recipient_territory,
		stone_params.t2m_divisor,
		stone_params.t2m_cap
	)
	if payout <= 0 then
		return
	end
	state.scores.plus_mult[recipient] = state.scores.plus_mult[recipient] + payout
end

return M
