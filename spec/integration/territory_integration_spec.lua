local helper = require("spec.spec_helper")

local function assert_expected_territory_ascii(case_name, before_rows, expected_rows)
	local b = helper.parse_board_ascii(before_rows)
	local territory_grid = helper.territory_map(b, "regional")
	helper.debug_dump_territory(case_name, b, territory_grid)
	assert.are.equal(table.concat(expected_rows, "\n"), helper.territory_ascii(b, territory_grid))
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
