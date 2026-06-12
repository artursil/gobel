--- Generic placement lifecycle runner: invokes effect ``on_placement`` hooks from stone definitions.
--- @module single_game.resolver.effect_placement_lifecycle

local config = require("config")
local content = require("content")
local objects_effects = require("objects.effects")

local M = {}

--- @param actor string ``"black"`` | ``"white"``
--- @return string owner ``config.OWNER_BLACK`` | ``config.OWNER_WHITE``
local function owner_for_actor(actor)
	if actor == "white" then
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- Runs ``on_placement`` hooks for every effect on ``stone_def`` at ``row,col``.
--- @param state table
--- @param stone_def table
--- @param row integer
--- @param col integer
--- @param actor string ``"black"`` | ``"white"``
--- @param board_snapshot table|nil board after placement (for group snapshot effects)
--- @return nil
function M.run(state, stone_def, row, col, actor, board_snapshot)
	if not stone_def or not stone_def.effects then
		return
	end
	local owner = owner_for_actor(actor)
	local cell = state.board[row] and state.board[row][col]
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		local resolved = objects_effects.resolve(effect_def)
		if resolved and resolved.on_placement then
			resolved.on_placement(state, owner, row, col, cell, effect_def, board_snapshot, actor)
		end
	end
end

--- Runs placement hooks for a placed stone id at ``row,col`` on ``state.board``.
--- @param state table
--- @param stone_id string
--- @param row integer
--- @param col integer
--- @param actor string ``"black"`` | ``"white"``
--- @param board_snapshot table|nil
--- @return nil
function M.run_for_stone_id(state, stone_id, row, col, actor, board_snapshot)
	local stone_def = content.get_stone(stone_id)
	M.run(state, stone_def, row, col, actor, board_snapshot)
end

return M
