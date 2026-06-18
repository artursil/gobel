local board = require("board")
local config = require("config")
local test_helper = require("spec.test_helper")
local territory_control_rounds = require("single_game.resolver.helpers.territory_control_rounds")

local ZERO_ROW = "+0 +0 +0 +0 +0 +0 +0 +0 +0"
local ZERO_ROWS = {}
for i = 1, config.BOARD_SIZE do
	ZERO_ROWS[i] = ZERO_ROW
end

describe("territory_control_rounds", function()
	local g

	before_each(function()
		g = test_helper.new_isolated_game()
		g.board = board.new()
		test_helper.set_territory_control_rounds_ascii(g, ZERO_ROWS)
	end)

	it("delayed start: first black-owned round stays +0", function()
		test_helper.seed_territory_owner_at_cell(g, 5, 5, "black")
		territory_control_rounds.tick(g)
		assert.are.equal(0, territory_control_rounds.get(g, 5, 5))
	end)

	it("delayed start: second black-owned round increments to +1", function()
		test_helper.seed_territory_owner_at_cell(g, 5, 5, "black")
		territory_control_rounds.tick(g)
		territory_control_rounds.tick(g)
		assert.are.equal(1, territory_control_rounds.get(g, 5, 5))
	end)

	it("continuing black control increments from +1", function()
		territory_control_rounds.set(g, 5, 5, 1)
		test_helper.seed_territory_owner_at_cell(g, 5, 5, "black")
		territory_control_rounds.tick(g)
		assert.are.equal(2, territory_control_rounds.get(g, 5, 5))
	end)

	it("owner flip resets streak to +0", function()
		territory_control_rounds.set(g, 5, 5, 3)
		test_helper.seed_territory_owner_at_cell(g, 5, 5, "white")
		territory_control_rounds.tick(g)
		assert.are.equal(0, territory_control_rounds.get(g, 5, 5))
	end)

	it("contested cell resets to +0", function()
		territory_control_rounds.set(g, 5, 5, 4)
		g.territory = g.territory or {}
		g.territory[5] = g.territory[5] or {}
		g.territory[5][5] = config.STONE_NONE
		territory_control_rounds.tick(g)
		assert.are.equal(0, territory_control_rounds.get(g, 5, 5))
	end)

	it("stone placement clears control at cell", function()
		territory_control_rounds.set(g, 5, 5, 5)
		territory_control_rounds.clear_cell(g, 5, 5)
		assert.are.equal(0, territory_control_rounds.get(g, 5, 5))
	end)

	it("set_territory_control_rounds_ascii seeds dense grid", function()
		test_helper.set_territory_control_rounds_ascii(g, {
			ZERO_ROW,
			ZERO_ROW,
			ZERO_ROW,
			ZERO_ROW,
			"+0 +0 +0 +0 +5 +0 +0 +0 +0",
			ZERO_ROW,
			ZERO_ROW,
			ZERO_ROW,
			ZERO_ROW,
		})
		test_helper.assert_territory_control_rounds_ascii(g, {
			ZERO_ROW,
			ZERO_ROW,
			ZERO_ROW,
			ZERO_ROW,
			"+0 +0 +0 +0 +5 +0 +0 +0 +0",
			ZERO_ROW,
			ZERO_ROW,
			ZERO_ROW,
			ZERO_ROW,
		})
	end)
end)
