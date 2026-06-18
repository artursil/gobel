--- Drain ``pending_stone_removals``: clear cells, prisoners, ``dispatch_removed``.
--- @module single_game.resolver.stages.remove_stones

local board = require("board")
local config = require("config")
local dispatch_removed = require("single_game.resolver.stages.dispatch_removed")
local match_state = require("match_state")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")
local stone_timers = require("single_game.resolver.stone_timers")
local effects_helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

--- @param ctx table ``{ state, actor, player_chain_color? }``
--- @return integer supplemental_captures prisoner count from drained enemy removals
--- @return boolean kamikaze_sacrifice_applies
function M.run(ctx)
	local state = ctx.state
	local actor = ctx.actor
	local player_chain_color = ctx.player_chain_color
	local entries = pending_removals.take_all(state)
	if #entries == 0 then
		return 0, false
	end

	local old_board = board.clone(state.board)
	local dispatch_opts = {
		capturer = actor,
		skip_sacrifice_cells = {},
	}
	local supplemental_captures = 0
	local kamikaze_sacrifice_applies = false

	for i = 1, #entries do
		local entry = entries[i]
		local row, col = entry.row, entry.col
		if row and col then
			local cell = state.board[row] and state.board[row][col]
			if cell and not board.is_empty(cell) then
				if entry.skip_on_removed then
					dispatch_opts.skip_sacrifice_cells[#dispatch_opts.skip_sacrifice_cells + 1] = {
						row = row,
						col = col,
					}
					kamikaze_sacrifice_applies = true
				else
					supplemental_captures = supplemental_captures + 1
					local capturer = entry.capturer or actor
					if player_chain_color
						and effects_helpers.mixed_surround_at_cell(state.board, row, col, player_chain_color) then
						effects_helpers.set_capture_cooldown(state, row, col, capturer)
					end
				end
				state.board[row][col] = config.STONE_NONE
			end
		end
	end

	dispatch_removed.run(state, old_board, state.board, dispatch_opts)
	stone_timers.clear_removed_stones(state, old_board, state.board)

	if supplemental_captures > 0 and actor then
		local actor_state = match_state.player_for_color(state, actor)
		actor_state.prisoners = actor_state.prisoners + supplemental_captures
	end

	return supplemental_captures, kamikaze_sacrifice_applies
end

return M
