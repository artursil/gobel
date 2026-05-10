local board = require("board")
local config = require("config")
local scoring = require("scoring")

local DEBUG_INTEGRATION = os.getenv("INTEGRATION_DEBUG") == "1"

local function place_stone(b, row, col, color)
	b[row][col] = board.make_stone(color, "stone_basic")
end

local function parse_board_ascii(rows)
	local b = board.new()
	for r = 1, #rows do
		local c = 1
		for token in string.gmatch(rows[r], "%S+") do
			if token == "B" then
				place_stone(b, r, c, config.STONE_BLACK)
			elseif token == "W" then
				place_stone(b, r, c, config.STONE_WHITE)
			end
			c = c + 1
		end
	end
	return b
end

local function board_ascii(b)
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

local function territory_ascii(b, territory_grid)
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

local function debug_dump(name, b, territory_grid)
	if not DEBUG_INTEGRATION then
		return
	end
	print("")
	print("[INTEGRATION_DEBUG] " .. name .. " initial board")
	print(board_ascii(b))
	print("[INTEGRATION_DEBUG] " .. name .. " territory assignment")
	print(territory_ascii(b, territory_grid))
end

local function assert_expected_territory_ascii(case_name, before_rows, expected_rows)
	local b = parse_board_ascii(before_rows)
	local territory_grid = scoring.territory_map(b, "regional")
	debug_dump(case_name, b, territory_grid)
	local expected = table.concat(expected_rows, "\n")
	local actual = territory_ascii(b, territory_grid)
	assert.are.equal(expected, actual)
end

describe("Territory ASCII integration (regular stones)", function()
	it("case 01: single black in center influence", function()
		assert_expected_territory_ascii("case_01", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b B b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
		})
	end)

	it("case 02: mirrored center tie", function()
		assert_expected_territory_ascii("case_02", {
			". . . . . . . . .",
			". B . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			"b b b b b b b b b",
			"b B b b b b b b b",
			"w b b b b b b b b",
			"W w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		})
	end)

	it("case 03: black ring with single empty center", function()
		assert_expected_territory_ascii("case_03", {
			"W . . . . . . . W",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B . B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . W",
		}, {
			"W w w b b b w w W",
			"w w b b b b b w w",
			"w b b B B B b b w",
			". b b B b B b b .",
			"b b b B B B b b b",
			"w b b b b b b b w",
			"w w b b b b b w w",
			"w w w b b b w w w",
			"W w w w w w w w W",
		})
	end)

	it("case 04: white edge pressure top-left", function()
		assert_expected_territory_ascii("case_04", {
			"B B . . W . . . .",
			"B . . W . . . . .",
			". W W . . . . . .",
			"W W . . . B . . .",
			". . . . W W . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			"B B w w W w w w w",
			"B w w W w w w w w",
			"w W W w w b b b b",
			"W W w w . B b b b",
			"w w w . W W w w w",
			"w . b B . w w w w",
			"w . b b . w w w w",
			"w . b b . w w w w",
			"w . b b . w w w w",
		})
	end)

	it("case 05: multiple enclosures", function()
		assert_expected_territory_ascii("case_05", {
			". . . W . . W . .",
			". B . W . . W . .",
			"B . W B B B W . .",
			". W B W . W B W B",
			". W B . W . B W .",
			". . W B B B . W .",
			". B . W . . . W .",
			"W W W . . . . . W",
			". . . . . . . . .",
		}, {
			"w w w W w w W w w",
			"w B w W w w W w w",
			"B w W B B B W w w",
			"w W B W w W B W B",
			"w W B b W b B W w",
			"w w W B B B b W w",
			"w B w W . b w W w",
			"W W W w w b w w W",
			"w w w w w b w w w",
		})
	end)

end)
