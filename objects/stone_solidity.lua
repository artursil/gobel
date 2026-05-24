--- Stone health (solidity): tier mapping and per-kind max values.
--- @module objects.stone_solidity

local content = require("content")
local stone_params = require("objects.parameters.stones")

local M = {}

--- Maps current/max solidity to atlas tier ``0`` (perfect) .. ``solidity_frame_count - 1`` (worst).
--- @param current integer
--- @param max integer|nil defaults to ``default_solidity``
--- @return integer tier 0..solidity_frame_count-1
function M.solidity_tier(current, max)
	local cap = max or stone_params.default_solidity
	if cap <= 0 then
		return stone_params.solidity_frame_count - 1
	end
	if current <= 0 then
		return stone_params.solidity_frame_count - 1
	end
	local ratio = current / cap
	if ratio > 0.75 then
		return 0
	end
	if ratio > 0.5 then
		return 1
	end
	if ratio > 0.25 then
		return 2
	end
	return stone_params.solidity_frame_count - 1
end

--- Max solidity for a stone kind (definition override or parameter default).
--- @param stone_id string
--- @return integer
function M.stone_max_solidity(stone_id)
	local def = content.get_stone(stone_id)
	if def and type(def.solidity) == "number" and def.solidity > 0 then
		return math.floor(def.solidity)
	end
	return stone_params.default_solidity
end

--- Current solidity for rendering; nil means full health for ``stone_id``.
--- @param stone_id string
--- @param solidity integer|nil
--- @return integer
function M.resolve_solidity(stone_id, solidity)
	if type(solidity) == "number" then
		return math.max(0, math.floor(solidity))
	end
	return M.stone_max_solidity(stone_id)
end

return M
