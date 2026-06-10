--- End-of-turn payout helpers for territory_to_points / territory_to_multiplier stones.
--- @module resolver.territory_stone_payout

local config = require("config")
local stone_params = require("objects.parameters.stones")

local M = {}

--- @return table
local function territory_module()
	return require("single_game.resolver.territory")
end

--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param stone_id string
--- @return boolean
local function is_territory_payout_stone(stone_id)
	return stone_id == "territory_to_multiplier_stone" or stone_id == "territory_to_points_stone"
end

--- @param territory_count integer
--- @param divisor integer
--- @param cap integer
--- @return integer
function M.payout_for_territory(territory_count, divisor, cap)
	if divisor <= 0 or territory_count <= 0 then
		return 0
	end
	return math.min(cap, math.floor(territory_count / divisor))
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param stone_id string
--- @return nil
function M.record_placement_snapshot(state, row, col, stone_id)
	if not is_territory_payout_stone(stone_id) then
		return
	end
	local territory_grid = state.territory
	if not territory_grid then
		return
	end
	local territory = territory_module()
	local owner = territory.owner_at_territory_cell(territory_grid, row, col)
	state.territory_stone_snapshots = state.territory_stone_snapshots or {}
	state.territory_stone_snapshots[cell_key(row, col)] = {
		owner = owner,
		black_total = territory.total_territory_for_owner(state, config.OWNER_BLACK),
		white_total = territory.total_territory_for_owner(state, config.OWNER_WHITE),
		placed_turn = state.turn_number or 1,
	}
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return "B"|"W"|nil owner
--- @return integer recipient_territory
local function resolve_recipient_and_territory(state, row, col)
	local key = cell_key(row, col)
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
	local territory = territory_module()
	local owner = territory.hypothetical_empty_owner(state, row, col)
	if not owner then
		return nil, 0
	end
	local total = territory.total_territory_for_owner(state, owner)
	return owner, total
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.apply_multiplier_payout(state, row, col)
	local owner, recipient_territory = resolve_recipient_and_territory(state, row, col)
	if not owner then
		return
	end
	local payout = M.payout_for_territory(recipient_territory, stone_params.t2m_divisor, stone_params.t2m_cap)
	if payout <= 0 then
		return
	end
	state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + payout
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.clear_snapshot(state, row, col)
	if not state.territory_stone_snapshots then
		return
	end
	state.territory_stone_snapshots[cell_key(row, col)] = nil
end

return M
