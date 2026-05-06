--- Object definition and instance modeling: stones
--- Unified source of truth: objects/definitions/stones.lua
--- @module objects.stones

local definitions = require("objects.definitions.stones")

local M = {}

--- Get stone definition by ID.
--- @param stone_id string
--- @return table|nil
function M.get(stone_id)
	return definitions[stone_id]
end

--- Get all stone definitions.
--- @return table
function M.all()
	return definitions
end

return M
