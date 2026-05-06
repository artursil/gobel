--- Object definition and instance modeling: stances
--- Unified source of truth: objects/definitions/stances.lua
--- @module objects.stances

local definitions = require("objects.definitions.stances")

local M = {}

--- Get stance definition by ID.
--- @param stance_id string
--- @return table|nil
function M.get(stance_id)
	return definitions[stance_id]
end

--- Get all stance definitions.
--- @return table
function M.all()
	return definitions
end

return M
