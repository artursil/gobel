--- State query helpers for resolver/effect/condition evaluation.
--- Centralizes derived reads from game state and transient resolution metadata.
--- @module resolver.state_queries

local content = require("content")
local config = require("config")

local M = {}

--- Maps side color to owner token (`config.OWNER_BLACK` / `config.OWNER_WHITE`).
--- @param side string
--- @return "B"|"W"
function M.owner_from_side(side)
	if side == "white" then
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- Ensures state.resolution exists with stable keys.
--- @param state table
--- @return table
function M.ensure_resolution(state)
	state.resolution = state.resolution or {}
	local r = state.resolution
	return r
end

--- Clears transient resolution metadata.
--- @param state table
--- @return nil
function M.clear_resolution(state)
	local r = M.ensure_resolution(state)
	r.phase = nil
	r.macro = nil
	r.sub = nil
	r.territory_step = nil
	r.effect_owner = nil
	r.source_owner = nil
	r.source_def_id = nil
	r.source_instance_id = nil
	r.source_object_type = nil
	r.source_stance_index = nil
	r.source_stance_slot_index = nil
	r.selected_target = nil
	r.selected_targets = nil
	r.trigger = nil
end

--- Returns current turn owner token.
--- @param state table
--- @return "B"|"W"|nil
function M.current_turn_owner(state)
	if not state or not state.to_play then
		return nil
	end
	return M.owner_from_side(state.to_play)
end

--- Returns the latest round stone event.
--- @param state table
--- @return table|nil
function M.last_round_stone_event(state)
	local events = state and state.round_stone_effects or nil
	if not events or #events == 0 then
		return nil
	end
	return events[#events]
end

--- Returns last placed stone metadata used by conditions.
--- @param state table
--- @return table|nil
function M.last_placed_stone(state)
	local event = M.last_round_stone_event(state)
	if not event then
		return nil
	end
	local stone_def = content.get_stone(event.stone_type)
	return {
		stone_id = event.stone_type,
		tags = (stone_def and stone_def.tags) or {},
	}
end

--- Returns selected target from transient resolution metadata.
--- @param state table
--- @return table|nil
function M.selected_target(state)
	local r = M.ensure_resolution(state)
	if r.selected_target == nil and type(r.selected_targets) == "table" then
		return r.selected_targets[1]
	end
	return r.selected_target
end

--- Returns selected targets from transient resolution metadata.
--- @param state table
--- @return table[]
function M.selected_targets(state)
	local r = M.ensure_resolution(state)
	if type(r.selected_targets) == "table" then
		return r.selected_targets
	end
	if r.selected_target ~= nil then
		return { r.selected_target }
	end
	return {}
end

--- Returns effect owner token from transient resolution metadata.
--- @param state table
--- @return "B"|"W"|nil
function M.effect_owner(state)
	local r = M.ensure_resolution(state)
	return r.effect_owner
end

--- Returns source owner token from transient resolution metadata.
--- @param state table
--- @return "B"|"W"|nil
function M.source_owner(state)
	local r = M.ensure_resolution(state)
	return r.source_owner
end

--- Returns source stance instance from ``state._stance_effect_order`` and ``source_stance_index``.
--- @param state table
--- @return table|nil
function M.source_stance_instance(state)
	local r = M.ensure_resolution(state)
	local idx = r.source_stance_index
	local order = state and state._stance_effect_order or nil
	if not idx or not order or not order[idx] then
		return nil
	end
	return order[idx].instance
end

--- Returns source stance row from ``state._stance_effect_order`` and ``source_stance_index``.
--- @param state table
--- @return table|nil
function M.source_stance_entry(state)
	local r = M.ensure_resolution(state)
	local idx = r.source_stance_index
	local order = state and state._stance_effect_order or nil
	if not idx or not order then
		return nil
	end
	return order[idx]
end

--- Returns source phase from transient resolution metadata.
--- @param state table
--- @return string|nil
function M.resolution_phase(state)
	local r = M.ensure_resolution(state)
	return r.sub or r.phase
end

--- @param state table
--- @return string|nil
function M.resolution_macro(state)
	local r = M.ensure_resolution(state)
	return r.macro
end

--- @param state table
--- @return string|nil
function M.resolution_sub(state)
	local r = M.ensure_resolution(state)
	return r.sub or r.phase
end

--- @param state table
--- @return string|nil
function M.resolution_territory_step(state)
	local r = M.ensure_resolution(state)
	return r.territory_step
end

--- Returns whether selected target points to an occupied board stone.
--- @param state table
--- @return boolean
function M.selected_target_exists(state)
	local target = M.selected_target(state)
	if not target or target.row == nil or target.col == nil then
		return false
	end
	local row = state.board and state.board[target.row]
	local cell = row and row[target.col]
	return cell ~= nil and cell ~= config.STONE_NONE
end

--- Returns selected target board cell.
--- @param state table
--- @return table|nil
function M.selected_target_cell(state)
	local target = M.selected_target(state)
	if not target or target.row == nil or target.col == nil then
		return nil
	end
	local row = state.board and state.board[target.row]
	return row and row[target.col] or nil
end

return M
