--- Static definition text plus optional live status lines from game state.
--- @module ui.object_descriptions

local M = {}

--- @param state table|nil
--- @param counter_key string
--- @param owner string
--- @return integer
local function run_counter_value(state, counter_key, owner)
	if not state or not state.run_state or not state.run_state.counters then
		return 0
	end
	local by_key = state.run_state.counters[counter_key]
	if not by_key then
		return 0
	end
	return by_key[owner] or 0
end

--- @param meta table
--- @param state table|nil
--- @param owner string
--- @return string|nil
local function status_run_counter(meta, state, owner)
	local value = run_counter_value(state, meta.counter_key, owner)
	if value == 0 then
		return nil
	end
	local label = meta.label or "Currently"
	if meta.signed then
		return string.format("%s: %+d", label, value)
	end
	return string.format("%s: %d", label, value)
end

--- @param meta table
--- @param state table|nil
--- @param owner string
--- @return string|nil
local function status_for_meta(meta, state, owner)
	if not meta or not meta.kind then
		return nil
	end
	if meta.kind == "run_counter" and meta.counter_key then
		return status_run_counter(meta, state, owner)
	end
	return nil
end

--- @param def table|nil
--- @param state table|nil
--- @param owner string
--- @return table
function M.get_lines(def, state, owner)
	local static = (def and def.description) or ""
	local status = status_for_meta(def and def.description_status, state, owner)
	return { static = static, status = status }
end

--- @param def table|nil
--- @param state table|nil
--- @param owner string
--- @return string
function M.get_full_text(def, state, owner)
	local lines = M.get_lines(def, state, owner)
	if lines.status and lines.status ~= "" then
		return lines.static .. "\n" .. lines.status
	end
	return lines.static
end

return M
