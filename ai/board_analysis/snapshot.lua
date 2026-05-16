--- Board and ko cloning for trial placements (no Love).
--- ``clone_ko`` is used when scoring post-move territory with updated ko bans.
--- Board cloning is handled inside ``rules.try_play``; MCTS rollouts may use both helpers in Phase 2.
--- @module ai.board_analysis.snapshot

local board = require("board")

local M = {}

--- @param b table
--- @return table
function M.clone_board(b)
	return board.clone(b)
end

--- @param ko table|nil
--- @return table|nil
function M.clone_ko(ko)
	if not ko then
		return nil
	end
	return { ko[1], ko[2] }
end

return M
