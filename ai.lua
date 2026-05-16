--- Thin re-export of the AI controller (legacy entry point).
--- @module ai

local controller = require("ai.controller")
local random_strategy = require("ai.strategies.random")

local M = {}

M.decide = controller.decide

--- @deprecated use ``ai.strategies.random`` or ``ai.controller.decide``
--- @param g table
--- @return integer|nil
--- @return integer|nil
function M.random_move(g)
	return random_strategy.random_move(g)
end

return M
