local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

--- Stone letter mapping (B=black basic, W=white, special letters = special black kinds)
local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	C = { color = config.STONE_BLACK, kind = "stone_power" },
	F = { color = config.STONE_BLACK, kind = "stone_focus" },
	L = { color = config.STONE_BLACK, kind = "stone_influence" },
	T = { color = config.STONE_BLACK, kind = "stone_tower" },
	S = { color = config.STONE_BLACK, kind = "stone_special" },
	X = { color = config.STONE_BLACK, kind = "wall" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	if def.color == config.STONE_BLACK then
		STONE_TO_LETTER[def.kind] = letter
	end
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_energy = test_helper.set_energy
local set_money = test_helper.set_money
local set_cards = test_helper.set_cards
local set_stances = test_helper.set_stances
local set_round = test_helper.set_round
local set_persistent_counter = test_helper.set_persistent_counter
local set_points = test_helper.set_points
local set_mult = test_helper.set_mult
local set_x_mult = test_helper.set_x_mult
local set_board = test_helper.set_board
local play_card = test_helper.play_card
local play_cards = test_helper.play_cards
local place_stone = test_helper.place_stone
local play_card_and_stone = test_helper.play_card_and_stone
local visual_score_snapshot = test_helper.visual_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_player_energy = test_helper.assert_player_energy
local assert_player_money = test_helper.assert_player_money
local assert_territory_ascii = test_helper.assert_territory_ascii
local assert_territory_values_ascii = test_helper.assert_territory_values_ascii
local assert_players_total_score = test_helper.assert_players_total_score
local assert_players_total_score_delta = test_helper.assert_players_total_score_delta
local assert_players_plus_mult_delta = test_helper.assert_players_plus_mult_delta

describe("Scoring visual spec", function()
	local g

	before_each(function()
		g = new_base_state()
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("case_01: card + basic stone at center owns full board, scores correctly", function()
		set_hand(g, "black", { "stone_basic" })
		set_energy(g, "black", 3)
		set_cards(g, "black", { "card_point_tap" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local snap = visual_score_snapshot(g)

		play_card_and_stone(g, 1, {
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

		assert_player_energy(g, "black", 2, "card_point_tap spends 1 energy")
		assert_player_money(g, "black", 0, "black starts with no money")

		assert_territory_ascii(g, {
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b B b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
		}, "center stone claims all empty cells for black")

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 # 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "each owned empty cell counts as territory value 1")

		local case01_total = P.case01_black_total_after_card_and_stone("card_point_tap", "stone_basic", 1)
		assert_players_total_score(g, case01_total, 0, "turn 1 center stone full-board score")
		assert_players_total_score_delta(g, snap, case01_total, 0, "score change from match start")
	end)

	it("persistent_flux round 1 basic stone: counter applied in full as mult", function()
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_basic" })
		set_round(g, 1)

		local snap = visual_score_snapshot(g)

		place_stone(g, {
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

		assert_players_plus_mult_delta(g, snap, P.persistent_flux_round1_plus_mult_delta(9), 0, "persistent_flux round 1 basic stone")
	end)

	it("persistent_flux round 1 special stone: counter incremented then applied in full", function()
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 1)

		local snap = visual_score_snapshot(g)

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . S . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_players_plus_mult_delta(
			g,
			snap,
			P.persistent_flux_round1_plus_mult_delta(P.persistent_flux_special_counter_after(9)),
			0,
			"persistent_flux round 1 special stone"
		)
	end)

	it("persistent_flux round 3 wall stone: pending delta applied (negative)", function()
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_wall" })
		set_round(g, 3)

		local snap = visual_score_snapshot(g)

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . X . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_players_plus_mult_delta(
			g,
			snap,
			P.persistent_flux_wall_effective_delta(9),
			0,
			"persistent_flux round 3 wall stone counter 9"
		)
	end)
	it("persistent_flux round 3 wall stone: pending delta applied (negative)", function()
		set_persistent_counter(g, "persistent_flux_mult", 2, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_wall" })
		set_round(g, 3)

		local snap = visual_score_snapshot(g)

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . X . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_players_plus_mult_delta(
			g,
			snap,
			P.persistent_flux_wall_effective_delta(2),
			0,
			"persistent_flux round 3 wall stone counter 2"
		)
	end)

	it("persistent_flux round 4 special stone: pending delta applied (positive)", function()
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 4)

		local snap = visual_score_snapshot(g)

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . S . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_players_plus_mult_delta(g, snap, P.persistent_flux_special_pending_delta(), 0, "persistent_flux round 4 special stone")
	end)

	it("blueprint + persistent_flux round 4 special stone: pending delta applied twice", function()
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_echo", "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 4)

		local snap = visual_score_snapshot(g)

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . S . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_players_plus_mult_delta(g, snap, P.persistent_flux_echo_pending_delta(2), 0, "echo + persistent_flux double pending")
	end)
	it("2 x blueprint + persistent_flux round 4 special stone: pending delta applied twice", function()
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_echo", "stance_echo", "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 4)

		local snap = visual_score_snapshot(g)

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . S . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_players_plus_mult_delta(g, snap, P.persistent_flux_echo_pending_delta(3), 0, "two echo + persistent_flux triple pending")
	end)
end)
