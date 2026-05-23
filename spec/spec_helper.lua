local board = require("board")
local config = require("config")
local territory_resolver = require("single_game.resolver.territory")

local M = {}

--- @return boolean
function M.integration_debug_enabled()
	return os.getenv("INTEGRATION_DEBUG") == "1"
end

--- Scoring helpers (moved from scoring.lua) ---

--- @param b table
--- @param territory_mode string|nil
--- @return table territory_grid
--- @return table decision_sources
--- @return table territory_value
function M.territory_map(b, territory_mode)
	return territory_resolver.compute_from_board(b, territory_mode or "regional")
end

--- Weighted controlled empty cells: sums ``territory_value[r][c]`` (default ``1``) for each empty matching ``color``.
--- When ``territory_value`` is omitted, counts tiles (weight ``1`` each).
--- @param territory table
--- @param color integer
--- @param territory_value table|nil
--- @return integer
function M.territory_points(territory, color, territory_value)
	local n = config.BOARD_SIZE
	local sum = 0
	for r = 1, n do
		for c = 1, n do
			if territory[r][c] == color then
				if territory_value then
					local w = (territory_value[r] and territory_value[r][c]) or 1
					sum = sum + w
				else
					sum = sum + 1
				end
			end
		end
	end
	return sum
end

--- @param b table
--- @param color integer
--- @param territory_mode string|nil
--- @return integer
function M.liberty_points(b, color, territory_mode)
	local territory, _, territory_value = M.territory_map(b, territory_mode)
	return M.territory_points(territory, color, territory_value)
end

--- Board ASCII helpers (B = black stone, W = white stone) ---

--- Parses a 9-row ASCII board using a custom letter→{color, kind} map.
--- Tokens not present in the map are treated as empty.
--- @param rows table
--- @param letter_to_stone table  map of letter string → { color: integer, kind: string }
--- @return table
function M.parse_board_ascii_kinds(rows, letter_to_stone)
	local b = board.new()
	for r = 1, #rows do
		local c = 1
		for token in string.gmatch(rows[r], "%S+") do
			local def = letter_to_stone[token]
			if def then
				b[r][c] = board.make_stone(def.color, def.kind)
			end
			c = c + 1
		end
	end
	return b
end

--- Renders a board using a custom kind→letter map for black stones; white always "W", empty ".".
--- @param b table
--- @param stone_to_letter table  map of stone kind string → letter string (for black stones)
--- @return string
function M.board_ascii_kinds(b, stone_to_letter)
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			local cell = b[r][c]
			if board.is_empty(cell) then
				row[#row + 1] = "."
			elseif cell.color == config.STONE_WHITE then
				row[#row + 1] = "W"
			else
				row[#row + 1] = stone_to_letter[cell.kind] or "B"
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

--- Parses a 9-row ASCII board. B = black, W = white, anything else = empty.
--- @param rows table
--- @return table
function M.parse_board_ascii(rows)
	local b = board.new()
	for r = 1, #rows do
		local c = 1
		for token in string.gmatch(rows[r], "%S+") do
			if token == "B" then
				b[r][c] = board.make_stone(config.STONE_BLACK, "stone_basic")
			elseif token == "W" then
				b[r][c] = board.make_stone(config.STONE_WHITE, "stone_basic")
			end
			c = c + 1
		end
	end
	return b
end

--- @param b table
--- @return string
function M.board_ascii(b)
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			local cell = b[r][c]
			if board.is_empty(cell) then
				row[#row + 1] = "."
			elseif cell.color == config.STONE_BLACK then
				row[#row + 1] = "B"
			else
				row[#row + 1] = "W"
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

--- Uppercase = stone (B/W), lowercase = owned empty (b/w), dot = neutral.
--- @param b table
--- @param territory_grid table
--- @return string
function M.territory_ascii(b, territory_grid)
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				row[#row + 1] = board.chain_color(cell) == config.STONE_BLACK and "B" or "W"
			else
				local owner = territory_grid[r][c]
				if owner == config.STONE_BLACK then
					row[#row + 1] = "b"
				elseif owner == config.STONE_WHITE then
					row[#row + 1] = "w"
				else
					row[#row + 1] = "."
				end
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

--- Uppercase = stone, lowercase = region-owned empty (b/w), dot = unowned.
--- @param b table
--- @param regions table
--- @param tiles table
--- @return string
function M.regions_ascii(b, regions, tiles)
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			if not board.is_empty(b[r][c]) then
				row[#row + 1] = board.chain_color(b[r][c]) == config.STONE_BLACK and "B" or "W"
			else
				local rid = tiles[r][c].region_id
				local owner = rid and regions[rid] and regions[rid].owner or nil
				if owner == "B" then
					row[#row + 1] = "b"
				elseif owner == "W" then
					row[#row + 1] = "w"
				else
					row[#row + 1] = "."
				end
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

--- Builds a fresh tile grid compatible with enclosure.detect_regions_and_ownership.
--- @return table
function M.new_tiles()
	local tiles = {}
	for r = 1, config.BOARD_SIZE do
		tiles[r] = {}
		for c = 1, config.BOARD_SIZE do
			tiles[r][c] = {
				influence = { B = 0, W = 0 },
				region_id = nil,
				override_owner = nil,
				owner = nil,
			}
		end
	end
	return tiles
end

--- Prints board + territory when INTEGRATION_DEBUG=1.
--- @param name string
--- @param b table
--- @param territory_grid table
--- @return nil
function M.debug_dump_territory(name, b, territory_grid)
	if not M.integration_debug_enabled() then
		return
	end
	print("")
	print("[INTEGRATION_DEBUG] " .. name .. " initial board")
	print(M.board_ascii(b))
	print("[INTEGRATION_DEBUG] " .. name .. " territory assignment")
	print(M.territory_ascii(b, territory_grid))
end

--- Prints board + region ownership when INTEGRATION_DEBUG=1.
--- @param name string
--- @param b table
--- @param regions table
--- @param tiles table
--- @return nil
function M.debug_dump_regions(name, b, regions, tiles)
	if not M.integration_debug_enabled() then
		return
	end
	print("")
	print("[INTEGRATION_DEBUG] " .. name .. " initial board")
	print(M.board_ascii(b))
	print("[INTEGRATION_DEBUG] " .. name .. " region ownership")
	print(M.regions_ascii(b, regions, tiles))
end

return M
