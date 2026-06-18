--- Orthogonal adjacent empty-cell territory override for control stones.
--- @module objects.effects_conditions.helpers.shared.control_territory_override

local board = require("board")
local config = require("config")

local M = {}

local ORTHOGONAL_OFFSETS = {
	{ -1, 0 },
	{ 1, 0 },
	{ 0, -1 },
	{ 0, 1 },
}

local function apply_control_override_to_tile(tile, owner)
	if tile.override_contested then
		return
	end
	if tile.override_owner == nil then
		tile.override_owner = owner
		return
	end
	if tile.override_owner == owner then
		return
	end
	tile.override_owner = nil
	tile.override_contested = true
end

--- Set override ownership on orthogonal adjacent empty cells for one control stone.
function M.apply_at(state, owner, row, col)
	local tiles = state.territory_tiles
	if not tiles then
		return
	end
	local n = config.BOARD_SIZE
	for i = 1, #ORTHOGONAL_OFFSETS do
		local nr = row + ORTHOGONAL_OFFSETS[i][1]
		local nc = col + ORTHOGONAL_OFFSETS[i][2]
		if nr >= 1 and nr <= n and nc >= 1 and nc <= n and board.is_empty(state.board[nr][nc]) then
			apply_control_override_to_tile(tiles[nr][nc], owner)
		end
	end
end

return M
