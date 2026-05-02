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
			if token == "A" then
				place_stone(b, r, c, config.STONE_BLACK)
			elseif token == "B" then
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
				row[#row + 1] = "A"
			else
				row[#row + 1] = "B"
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
				row[#row + 1] = board.chain_color(cell) == config.STONE_BLACK and "A" or "B"
			else
				local owner = territory_grid[r][c]
				if owner == config.STONE_BLACK then
					row[#row + 1] = "a"
				elseif owner == config.STONE_WHITE then
					row[#row + 1] = "b"
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
			". . . . A . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			"a a a a a a a a a",
			"a a a a a a a a a",
			"a a a a a a a a a",
			"a a a a a a a a a",
			"a a a a A a a a a",
			"a a a a a a a a a",
			"a a a a a a a a a",
			"a a a a a a a a a",
			"a a a a a a a a a",
		})
	end)

	it("case 02: mirrored center tie", function()
		assert_expected_territory_ascii("case_02", {
			". . . . . . . . .",
			". A . . . . . . .",
			". . . . . . . . .",
			"B . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			"a a a a a a a a a",
			"a A a a a a a a a",
			"b a a a a a a a a",
			"B b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
		})
	end)

	-- it("case 03: black ring with single empty center", function()
	-- 	assert_expected_territory_ascii("case_03", {
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . A A A . . .",
	-- 		". . . A . A . . .",
	-- 		". . . A A A . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 	}, {
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . A A A . . .",
	-- 		". . . A a A . . .",
	-- 		". . . A A A . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 	})
	-- end)

	-- it("case 04: white edge pressure top-left", function()
	-- 	assert_expected_territory_ascii("case_04", {
	-- 		"B B . . . . . . .",
	-- 		"B . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 	}, {
	-- 		"B B b . . . . . .",
	-- 		"B b . . . . . . .",
	-- 		"b . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 	})
	-- end)

	-- it("case 05: diagonal split", function()
	-- 	assert_expected_territory_ascii("case_05", {
	-- 		"A . . . . . . . .",
	-- 		". A . . . . . . .",
	-- 		". . A . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . B . .",
	-- 		". . . . . . . B .",
	-- 		". . . . . . . . B",
	-- 		". . . . . . . . .",
	-- 	}, {
	-- 		"A a . . . . . . .",
	-- 		"a A a . . . . . .",
	-- 		". a A a . . . . .",
	-- 		". . a . . . . . .",
	-- 		". . . . . . b . .",
	-- 		". . . . . . B b .",
	-- 		". . . . . b . B b",
	-- 		". . . . . . b . B",
	-- 		". . . . . . . b .",
	-- 	})
	-- end)

	-- it("case 06: center line multi-quarter interaction", function()
	-- 	assert_expected_territory_ascii("case_06", {
	-- 		". . . . A . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		"B . . . . . . . A",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . B . . . .",
	-- 	}, {
	-- 		". . . . A . . . .",
	-- 		". . . . a . . . .",
	-- 		". . . . . . . . .",
	-- 		"b . . . . . . . a",
	-- 		"B b . . . . . a A",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . b . . . .",
	-- 		". . . . B . . . .",
	-- 	})
	-- end)

	-- it("case 07: sparse four-corner stones", function()
	-- 	assert_expected_territory_ascii("case_07", {
	-- 		"A . . . . . . . B",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		"B . . . . . . . A",
	-- 	}, {
	-- 		"A a . . . . . b B",
	-- 		"a . . . . . . . b",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		"b . . . . . . . a",
	-- 		"B b . . . . . a A",
	-- 	})
	-- end)

	-- it("case 08: opposing horizontal walls", function()
	-- 	assert_expected_territory_ascii("case_08", {
	-- 		". . . . . . . . .",
	-- 		"A A A A A . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . B B B B B",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 	}, {
	-- 		"a a a a a . . . .",
	-- 		"A A A A A a . . .",
	-- 		"a a a a a . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . b b b b",
	-- 		". . . . B B B B B",
	-- 		". . . . b b b b b",
	-- 		". . . . . . . . .",
	-- 	})
	-- end)

	-- it("case 09: near-center mixed cluster", function()
	-- 	assert_expected_territory_ascii("case_09", {
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . A B . . . .",
	-- 		". . . B A . . . .",
	-- 		". . . . A . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 	}, {
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . A B b . . .",
	-- 		". . . B A a . . .",
	-- 		". . . . A a . . .",
	-- 		". . . . a . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 	})
	-- end)

	-- it("case 10: broad mixed top-half pressure", function()
	-- 	assert_expected_territory_ascii("case_10", {
	-- 		"A A A . . . B B B",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 	}, {
	-- 		"A A A a . b B B B",
	-- 		"a a a . . . b b b",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 		". . . . . . . . .",
	-- 	})
	-- end)
end)
