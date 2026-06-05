local config = require("config")
local helper = require("spec.spec_helper")

-- Stone letter mapping:
--   B  = black, stone_basic
--   W  = white, stone_basic
--   C  = black, stone_power
--   F  = black, stone_focus
--   L  = black, stone_influence
--   T  = black, stone_tower
--   .  = empty

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	C = { color = config.STONE_BLACK, kind = "stone_power" },
	F = { color = config.STONE_BLACK, kind = "stone_focus" },
	L = { color = config.STONE_BLACK, kind = "stone_influence" },
	T = { color = config.STONE_BLACK, kind = "stone_tower" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	if def.color == config.STONE_BLACK then
		STONE_TO_LETTER[def.kind] = letter
	end
end

local function parse_board(rows)
	return helper.parse_board_ascii_kinds(rows, LETTER_TO_STONE)
end

local board = require("board")

local function territory_value_ascii(b, territory_value)
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			if not board.is_empty(b[r][c]) then
				row[#row + 1] = "#"
			else
				local v = (territory_value and territory_value[r] and territory_value[r][c]) or 1
				row[#row + 1] = tostring(v)
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

local function print_case(name, b, territory, territory_value)
	local actual_black = helper.territory_points(territory, config.STONE_BLACK, territory_value)
	local actual_white = helper.territory_points(territory, config.STONE_WHITE, territory_value)
	print("\n=== " .. name .. " ===")
	print("result board:")
	print(helper.board_ascii_kinds(b, STONE_TO_LETTER))
	print("actual territory (b/w = empty owned, B/W = stone):")
	print(helper.territory_ascii(b, territory))
	print("territory value board (per-empty-cell multiplier; #=stone):")
	print(territory_value_ascii(b, territory_value))
	print(string.format("scores — black: %d  white: %d", actual_black, actual_white))
end

local function assert_territory(b, territory, expected_rows)
	assert.are.equal(table.concat(expected_rows, "\n"), helper.territory_ascii(b, territory))
end

local function assert_territory_values(b, territory_value, expected_rows)
	assert.are.equal(table.concat(expected_rows, "\n"), territory_value_ascii(b, territory_value))
end

local function assert_scores(territory, territory_value, expected_black, expected_white)
	assert.are.equal(expected_black, helper.territory_points(territory, config.STONE_BLACK, territory_value))
	assert.are.equal(expected_white, helper.territory_points(territory, config.STONE_WHITE, territory_value))
end

describe("Territory scoring integration", function()
	it("case_01: single black in center", function()
		local b = parse_board({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local territory, _, territory_value = helper.territory_map(b, "regional")
		print_case("case_01", b, territory, territory_value)
		assert_territory(b, territory, {
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
		assert_scores(territory, territory_value, 81, 0)
	end)

-- 	it("case_02: black vs white", function()
-- 		local b = parse_board({ ... })
-- 		local territory = helper.territory_map(b, "regional")
-- 		print_case("case_02", b, territory)
-- 		assert_territory(b, territory, { ... })
-- 		assert_scores(territory, 0, 0)
-- 	end)

-- 	it("case_03: lieutenant (L) extends black reach", function()
-- 		local b = parse_board({ ... })
-- 		local territory = helper.territory_map(b, "regional")
-- 		print_case("case_03", b, territory)
-- 		assert_territory(b, territory, { ... })
-- 		assert_scores(territory, 0, 0)
-- 	end)

	it("case_04: tower (T) in top-left corner with white at mid-right", function()
		local b = parse_board({
			"T . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local territory, _, territory_value = helper.territory_map(b, "regional")
		print_case("case_04", b, territory, territory_value)
		assert_territory_values(b, territory_value, {
			"# 2 2 1 1 1 1 1 1",
			"2 2 2 1 1 1 1 1 1",
			"2 2 2 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 #",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		})
	end)

	it("case_04_5: 2x towers", function()
		local b = parse_board({
			"T . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
			". . . . . . . . .",
			". . W . . . . . .",
			". . . . . . . . .",
			"T . . . . . . . .",
		})
		local territory, _, territory_value = helper.territory_map(b, "regional")
		print_case("case_04", b, territory, territory_value)
		assert_territory_values(b, territory_value, {
			"# 2 2 1 1 1 1 1 1",
			"2 2 2 1 1 1 1 1 1",
			"2 2 2 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 #",
			"1 1 1 1 1 1 1 1 1",
			"2 2 # 1 1 1 1 1 1",
			"2 2 2 1 1 1 1 1 1",
			"# 2 2 1 1 1 1 1 1",
		})
	end)

-- 	it("case_05: mixed special blacks vs white", function()
-- 		local b = parse_board({ ... })
-- 		local territory = helper.territory_map(b, "regional")
-- 		print_case("case_05", b, territory)
-- 		assert_territory(b, territory, { ... })
-- 		assert_territory_values(b, territory, { ... })
-- 		assert_scores(territory, 0, 0)
-- 	end)
end)
