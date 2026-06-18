--- Unified per-cell countdown field and legacy timer migration.
--- @module objects.effects_conditions.helpers.shared.duration_left

local M = {}

--- Copy legacy timer fields into ``duration_left`` when present and unified field is absent.
--- @param cell table
--- @return nil
function M.migrate_legacy_fields(cell)
	if cell.duration_left ~= nil then
		return
	end
	if type(cell.survival_rounds_remaining) == "number" then
		cell.duration_left = cell.survival_rounds_remaining
		cell.survival_rounds_remaining = nil
		cell.timer_remaining_rounds = nil
		return
	end
	if type(cell.immunity_remaining) == "number" then
		cell.duration_left = cell.immunity_remaining
		cell.immunity_remaining = nil
		return
	end
end

--- @param cell table
--- @return boolean
function M.has_timer(cell)
	M.migrate_legacy_fields(cell)
	return cell.duration_left ~= nil
end

--- @param cell table
--- @return integer
function M.remaining(cell)
	M.migrate_legacy_fields(cell)
	return cell.duration_left or 0
end

--- Decrement ``duration_left`` once; keeps ``0`` at expiry for tick effects.
--- @param cell table
--- @return nil
function M.decrement_cell(cell)
	M.migrate_legacy_fields(cell)
	local remaining = cell.duration_left
	if type(remaining) ~= "number" or remaining <= 0 then
		return
	end
	cell.duration_left = remaining - 1
end

--- Clear countdown state on a cell.
--- @param cell table
--- @return nil
function M.clear(cell)
	cell.duration_left = nil
	cell.survival_rounds_remaining = nil
	cell.timer_remaining_rounds = nil
	cell.immunity_remaining = nil
	cell.delay_payout = nil
end

--- Mark a cell to skip the generic tick decrement on the placement turn's end-of-turn only.
--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.set_tick_skip_for_placement(state, row, col)
	state._effect_tick_skip_cell = {
		row = row,
		col = col,
		turn = state.turn_number or 1,
	}
end

--- @param state table
--- @return table|nil ``{ row, col }`` when skip applies on this turn
function M.resolve_tick_skip(state)
	local skip = state._effect_tick_skip_cell
	if type(skip) ~= "table" then
		return nil
	end
	if skip.turn ~= nil and skip.turn ~= (state.turn_number or 1) then
		return nil
	end
	return skip
end

return M
