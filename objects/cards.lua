--- Object definition and instance modeling: playing cards
--- Unified source of truth: objects/definitions/cards.lua
--- @module objects.cards

local definitions = require("objects.definitions.cards")

local M = {}

--- Get card definition by ID.
--- @param card_id string
--- @return table|nil
function M.get(card_id)
	return definitions[card_id]
end

--- Get all card definitions.
--- @return table
function M.all()
	return definitions
end

return M
