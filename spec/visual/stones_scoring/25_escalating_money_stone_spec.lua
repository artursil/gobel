--- Visual spec: escalating_money_stone (OBJECTS.md #25).
---
--- Stone under test: escalating_money_stone
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	T = { color = config.STONE_BLACK, kind = "tax_stone" },
	Y = { color = config.STONE_BLACK, kind = "territory_to_points_stone" },
	Z = { color = config.STONE_BLACK, kind = "territory_to_multiplier_stone" },
	R = { color = config.STONE_BLACK, kind = "escalating_money_stone" },
	K = { color = config.STONE_BLACK, kind = "blockade_stone" },
	I = { color = config.STONE_BLACK, kind = "influence_stone" },
	i = { color = config.STONE_WHITE, kind = "influence_stone" },
	O = { color = config.STONE_BLACK, kind = "control_stone" },
	o = { color = config.STONE_WHITE, kind = "control_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_stone_instance = test_helper.set_stone_instance
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_money = test_helper.assert_player_money
local assert_territory_ascii = test_helper.assert_territory_ascii

local S = P.stone

--- @return number
local function tax_money_per_enemy()
	return S.tax_money_per_enemy or 1
end

--- @return number
local function tax_points_per_enemy()
	return S.tax_points_per_enemy or 1
end

--- @param enemy_count integer
--- @return number
local function tax_money_total(enemy_count)
	return enemy_count * tax_money_per_enemy()
end

--- @param enemy_count integer
--- @return number
local function tax_points_total(enemy_count)
	return enemy_count * tax_points_per_enemy()
end

--- @return number
local function t2p_divisor()
	return S.t2p_divisor or 4
end

--- @return number
local function t2p_cap()
	return S.t2p_cap or 12
end

--- @return number
local function t2m_divisor()
	return S.t2m_divisor or 6
end

--- @return number
local function t2m_cap()
	return S.t2m_cap or 8
end

--- @param territory_total integer
--- @return number
local function t2p_payout(territory_total)
	return math.min(t2p_cap(), math.floor(territory_total / t2p_divisor()))
end

--- @param territory_total integer
--- @return number
local function t2m_payout(territory_total)
	return math.min(t2m_cap(), math.floor(territory_total / t2m_divisor()))
end

--- @return number
local function ems_round_money()
	return S.ems_round_money or 1
end

--- @return number
local function ems_capture_multiplier()
	return S.ems_capture_multiplier or 2
end

--- @param received number
--- @return number
local function ems_capture_penalty(received)
	return ems_capture_multiplier() * received
end

--- @param g table
--- @param side string
--- @return integer
local function territory_cell_count(g, side)
	return test_helper.count_territory_cells(g, side)
end

local function blank_board()
	return {
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
	}
end

local STONE_IDS = {
	"tax_stone",
	"territory_to_points_stone",
	"territory_to_multiplier_stone",
	"escalating_money_stone",
}

describe("escalating_money_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"escalating_money_stone"}, "escalating_money_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("escalating_money_stone", function()
		it("first black end of turn adds EMS_ROUND_MONEY", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)
			assert_player_money(g, "black", snap.money + ems_round_money(), "first escalating money tick")
		end)

		it("two survived turns accumulate 2x EMS_ROUND_MONEY received", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)
			test_helper.finish_turn(g)
			assert_player_money(g, "black", snap.money + 2 * ems_round_money(), "two ticks cumulative")
		end)

		it("N survived turns accumulate Nx EMS_ROUND_MONEY received", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			local turns = 4
			for _ = 1, turns do
				test_helper.finish_turn(g)
			end
			assert_player_money(g, "black", snap.money + turns * ems_round_money(), "N turn cumulative")
		end)

		it("enemy capture charges EMS_CAPTURE_MULTIPLIER times total received", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			test_helper.finish_turn(g)
			local received = 2 * ems_round_money()
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			assert_player_money(g, "black", snap.money - ems_capture_penalty(received), "capture penalty from cumulative received")
		end)

		it("capture penalty clamps money at global floor", function()
			set_hand(g, "black", { "escalating_money_stone" })
			test_helper.set_money(g, "black", 1)
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			for _ = 1, 3 do
				test_helper.finish_turn(g)
			end
			test_helper.capture_stone_at(g, 5, 5, "black")
			assert_player_money(g, "black", 0, "money clamp at floor")
		end)

		it("EMS_CAPTURE_MULTIPLIER 2 makes penalty exactly double received", function()
			local mult = 2
			test_helper.set_stone_parameter(g, "escalating_money_stone", "ems_capture_multiplier", mult)
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			local received = ems_round_money()
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			assert_player_money(g, "black", snap.money - mult * received, "double penalty")
		end)

		it("EMS_CAPTURE_MULTIPLIER 3 makes penalty exactly triple received", function()
			test_helper.set_stone_parameter(g, "escalating_money_stone", "ems_capture_multiplier", 3)
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			test_helper.finish_turn(g)
			local received = 2 * ems_round_money()
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			assert_player_money(g, "black", snap.money - 3 * received, "triple penalty")
		end)

		it("self removal without enemy capture charges no penalty", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			assert_player_money(g, "black", snap.money, "self removal no enemy penalty")
		end)

		it("two stones penalize only captured stone cumulative received", function()
			set_hand(g, "black", { "escalating_money_stone", "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . R . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . R R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.finish_turn(g)
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 4, "black")
			assert_player_money(
				g,
				"black",
				snap.money - ems_capture_penalty(ems_round_money()),
				"only captured stone total"
			)
		end)

		it("late capture penalty uses full cumulative received", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			local turns = 5
			for _ = 1, turns do
				test_helper.finish_turn(g)
			end
			local received = turns * ems_round_money()
			test_helper.capture_stone_at(g, 5, 5, "black")
			assert_player_money(
				g,
				"black",
				snap.money + received - ems_capture_penalty(received),
				"late penalty uses full tracked total"
			)
		end)
	end)
end)
