local board = require("board")
local config = require("config")
local scoring = require("scoring")

-- Stone letter mapping:
--   B  = black, stone_basic
--   W  = white, stone_basic
--   C  = black, stone_power
--   F  = black, stone_focus
--   L  = black, stone_lieutenant
--   T  = black, stone_tower
--   .  = empty

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	C = { color = config.STONE_BLACK, kind = "stone_power" },
	F = { color = config.STONE_BLACK, kind = "stone_focus" },
	L = { color = config.STONE_BLACK, kind = "stone_lieutenant" },
	T = { color = config.STONE_BLACK, kind = "stone_tower" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	if def.color == config.STONE_BLACK then
		STONE_TO_LETTER[def.kind] = letter
	end
end

local function parse_board_ascii(rows)
	local b = board.new()
	for r = 1, #rows do
		local c = 1
		for token in string.gmatch(rows[r], "%S+") do
			local def = LETTER_TO_STONE[token]
			if def then
				b[r][c] = board.make_stone(def.color, def.kind)
			end
			c = c + 1
		end
	end
	return b
end

local function result_board_ascii(b)
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
				row[#row + 1] = STONE_TO_LETTER[cell.kind] or "B"
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

local function expected_board_ascii(rows)
	return table.concat(rows, "\n")
end

local function territory_value_ascii(b, territory)
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			if not board.is_empty(b[r][c]) then
				row[#row + 1] = "#"
			elseif territory[r][c] == config.STONE_BLACK then
				row[#row + 1] = "1"
			elseif territory[r][c] == config.STONE_WHITE then
				row[#row + 1] = "2"
			else
				row[#row + 1] = "0"
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

local function territory_ownership_ascii(b, territory)
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				row[#row + 1] = cell.color == config.STONE_BLACK and "B" or "W"
			elseif territory[r][c] == config.STONE_BLACK then
				row[#row + 1] = "b"
			elseif territory[r][c] == config.STONE_WHITE then
				row[#row + 1] = "w"
			else
				row[#row + 1] = "."
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

local function run_case(name, input_rows, expected_rows, expected_black, expected_white)
	local b = parse_board_ascii(input_rows)
	local territory = scoring.territory_map(b, "regional")

	local actual_black = scoring.territory_points(territory, config.STONE_BLACK)
	local actual_white = scoring.territory_points(territory, config.STONE_WHITE)

	print("\n=== " .. name .. " ===")
	print("result board:")
	print(result_board_ascii(b))
	print("expected territory (b/w = empty owned by black/white, B/W = stone):")
	print(expected_board_ascii(expected_rows))
	print("actual territory:")
	print(territory_ownership_ascii(b, territory))
	print("territory value board (1=black empty, 2=white empty, 0=neutral, #=stone):")
	print(territory_value_ascii(b, territory))
	print(string.format("scores — black: %d (expected %d)  white: %d (expected %d)", actual_black, expected_black, actual_white, expected_white))

	assert.are.equal(expected_board_ascii(expected_rows), territory_ownership_ascii(b, territory))
	assert.are.equal(expected_black, scoring.territory_points(territory, config.STONE_BLACK))
	assert.are.equal(expected_white, scoring.territory_points(territory, config.STONE_WHITE))
end

describe("Territory scoring integration", function()
	it("case_01: single black in center", function()
		run_case("case_01", {
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
		}, 81, 0)
	end)
end)

-- 	it("case_02: black vs white", function()
-- 		run_case("case_02", {
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 		}, {
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 		}, 0, 0)
-- 	end)

-- 	it("case_03: lieutenant (L) extends black reach", function()
-- 		run_case("case_03", {
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 		}, {
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 		}, 0, 0)
-- 	end)

-- 	it("case_04: tower (T) in corner doubles nearby territory value", function()
-- 		run_case("case_04", {
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 		}, {
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 		}, 0, 0)
-- 	end)

-- 	it("case_05: mixed special blacks vs white", function()
-- 		run_case("case_05", {
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 			". . . . . . . . .",
-- 		}, {
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 			"FILL ME",
-- 		}, 0, 0)
-- 	end)
-- end)
