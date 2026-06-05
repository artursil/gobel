--- Visual spec: unlimited_upgrades_stone (OBJECTS.md #27).
---
--- Stone under test: unlimited_upgrades_stone
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	P = { color = config.STONE_BLACK, kind = "points_3_rounds_stone" },
	S = { color = config.STONE_BLACK, kind = "self_destruct_timed_stone" },
	F = { color = config.STONE_BLACK, kind = "final_blow_stone" },
	U = { color = config.STONE_BLACK, kind = "unlimited_upgrades_stone" },
	f = { color = config.STONE_WHITE, kind = "final_blow_stone" },
	R = { color = config.STONE_BLACK, kind = "retrigger_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_stone_instance = test_helper.set_stone_instance
local set_round = test_helper.set_round
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_board_cell_empty = test_helper.assert_board_cell_empty
local assert_stone_timer = test_helper.assert_stone_timer

local S = P.stone

--- @return number
local function points_delay_rounds()
	return S.points_delay_rounds or 7
end

--- @return number
local function points_delay_payout()
	return S.points_delay_payout or P.stone_effect_value("points_3_rounds_stone", "add_points") or 20
end

--- @return number
local function self_destruct_immediate()
	return S.self_destruct_immediate_points or P.stone_effect_value("self_destruct_timed_stone", "add_points") or 8
end

--- @return number
local function self_destruct_delay()
	return S.self_destruct_delay_rounds or 2
end

--- @return number
local function final_blow_points()
	return S.final_blow_points or P.stone_effect_value("final_blow_stone", "add_points") or 30
end

--- @return number
local function final_blow_plus_mult()
	return S.final_blow_plus_mult or P.stone_effect_value("final_blow_stone", "add_mult") or 10
end

--- @return number
local function final_blow_nonfinal_points()
	return S.final_blow_nonfinal_points or 1
end

--- @param level integer
--- @return number
local function unlimited_level_points(level)
	local per = S.unlimited_upgrades_points_per_level or P.stone_effect_value("unlimited_upgrades_stone", "add_points") or 1
	return per * level
end

--- @param level integer
--- @return number
local function unlimited_level_plus_mult(level)
	local per = S.unlimited_upgrades_plus_mult_per_level or P.stone_effect_value("unlimited_upgrades_stone", "add_mult") or 1
	return per * level
end

local STONE_IDS = {
	"points_3_rounds_stone",
	"self_destruct_timed_stone",
	"final_blow_stone",
	"unlimited_upgrades_stone",
}

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

describe("unlimited_upgrades_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"unlimited_upgrades_stone"}, "unlimited_upgrades_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("unlimited_upgrades_stone", function()
		it("unlimited_upgrades_stone scenario 1: upgrade increases level by one", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 2)
			test_helper.upgrade_stone_instance(g, "black", 1)
			test_helper.assert_stone_instance_level(g, "black", 1, 3, "level increments")
		end)

		it("unlimited_upgrades_stone scenario 2: level beyond normal cap still upgrades", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 5)
			test_helper.upgrade_stone_instance(g, "black", 1)
			test_helper.assert_stone_instance_level(g, "black", 1, 6, "no cap on level")
		end)

		it("unlimited_upgrades_stone scenario 3: sequential upgrades step by one", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 1)
			test_helper.upgrade_stone_instance(g, "black", 1)
			test_helper.upgrade_stone_instance(g, "black", 1)
			test_helper.assert_stone_instance_level(g, "black", 1, 3, "two upgrades")
		end)

		it("unlimited_upgrades_stone scenario 4: placement payout scales with level", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 4)
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . U . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, unlimited_level_points(4), "level 4 points scaling")
			assert_player_plus_mult_delta(g, "black", snap, unlimited_level_plus_mult(4), "level 4 mult scaling")
		end)

		it("unlimited_upgrades_stone scenario 5: upgrade cost follows configured growth", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 2)
			local cost_before = test_helper.upgrade_cost_for_level(g, "unlimited_upgrades_stone", 2)
			test_helper.upgrade_stone_instance(g, "black", 1)
			local cost_after = test_helper.upgrade_cost_for_level(g, "unlimited_upgrades_stone", 3)
			assert.is_true(cost_after >= cost_before, "upgrade cost non-decreasing")
		end)

		it("unlimited_upgrades_stone scenario 6: insufficient resources block upgrade", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 1)
			test_helper.set_money(g, "black", 0)
			test_helper.upgrade_stone_instance(g, "black", 1, { expect_success = false })
			test_helper.assert_stone_instance_level(g, "black", 1, 1, "level unchanged without money")
		end)

		it("unlimited_upgrades_stone scenario 7: high level placement has no precision corruption", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 12)
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . U . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, unlimited_level_points(12), "stress level payout exact")
		end)

		it("unlimited_upgrades_stone scenario 8: new instance after removal resets level", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 5)
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . U . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.capture_stone_at(g, 4, 4, "white")
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 1)
			test_helper.assert_stone_instance_level(g, "black", 1, 1, "fresh instance level 1")
		end)

		it("unlimited_upgrades_stone scenario 9: upgrading one instance leaves other unchanged", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 2)
			set_stone_instance(g, "black", 2, "unlimited_upgrades_stone", 2)
			test_helper.upgrade_stone_instance(g, "black", 1)
			test_helper.assert_stone_instance_level(g, "black", 1, 3, "slot 1 upgraded")
			test_helper.assert_stone_instance_level(g, "black", 2, 2, "slot 2 unchanged")
		end)

		it("unlimited_upgrades_stone scenario 10: restored instance keeps level and scaling", function()
			set_stone_instance(g, "black", 1, "unlimited_upgrades_stone", 5)
			local saved = test_helper.save_game_snapshot(g)
			test_helper.restore_game_snapshot(g, saved)
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . U . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, unlimited_level_points(5), "persisted level scaling")
		end)
	end)
end)
