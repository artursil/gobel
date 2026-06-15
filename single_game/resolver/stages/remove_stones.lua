--- After placement commit: board hygiene (extra capture, sacrifice removal).
--- @module single_game.resolver.stages.remove_stones

local board = require("board")
local config = require("config")
local content = require("content")
local effects_helpers = require("objects.effects_helpers")

local M = {}

--- @param stone_def table|nil
--- @return boolean
local function stone_def_has_kamikaze(stone_def)
	if not stone_def or not stone_def.effects then
		return false
	end
	for i = 1, #stone_def.effects do
		if stone_def.effects[i].effect_name == "kamikaze_sacrifice" then
			return true
		end
	end
	return false
end

--- @param ctx table ``{ state, actor, row, col, stone_id, stone_def, old_board }``
--- @return integer extra_captures
--- @return boolean kamikaze_sacrifice_applies
function M.run(ctx)
	local state = ctx.state
	local row, col = ctx.row, ctx.col
	local stone_def = ctx.stone_def or content.get_stone(ctx.stone_id)
	local extra_captures = 0
	local kamikaze_sacrifice_applies = false

	if stone_def and effects_helpers.stone_def_has_capture_zero_liberty_effect(stone_def) and ctx.old_board then
		local player_chain_color = ctx.player_chain_color
		if player_chain_color == nil and ctx.actor then
			player_chain_color = ctx.actor == "white" and config.STONE_WHITE or config.STONE_BLACK
		end
		effects_helpers.apply_capture_cooldowns_for_removals(
			state,
			ctx.old_board,
			state.board,
			ctx.actor,
			player_chain_color
		)
		local new_board, captures = effects_helpers.apply_zero_liberty_enemy_capture(
			state.board,
			state,
			ctx.actor,
			player_chain_color
		)
		state.board = new_board
		extra_captures = captures
	end

	if stone_def and stone_def_has_kamikaze(stone_def) and row and col then
		kamikaze_sacrifice_applies = true
		state.board[row][col] = config.STONE_NONE
	end

	return extra_captures, kamikaze_sacrifice_applies
end

return M
