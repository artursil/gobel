--- Visual spec: territory_to_multiplier_stone (OBJECTS.md #23).
---
--- Stone under test: territory_to_multiplier_stone
--- End-of-turn trigger: determines territory owner at stone cell,
--- computes min(S.t2m_cap, floor(owner_territory / S.t2m_divisor)),
--- adds payout to that owner's plus_mult. Payout tracks live territory each turn.
--- Structurally parallel to territory_to_points_stone but outputs plus_mult.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	Z = { color = config.STONE_BLACK, kind = "territory_to_multiplier_stone" },
	z = { color = config.STONE_WHITE, kind = "territory_to_multiplier_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_territory_ascii = test_helper.assert_territory_ascii

local S = P.stone

describe("territory_to_multiplier_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "territory_to_multiplier_stone" }, "territory_to_multiplier_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	-- ── basic payout ──────────────────────────────────────────────────

	it("single Z at center owns entire board, plus_mult hits cap", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
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
		}, "sole stone claims all 80 empty cells")

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = S.t2m_cap
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "80 / t2m_divisor exceeds cap")
	end)

	it("Z on split board with W gives moderate plus_mult below cap", function()
		set_board(g, {
			". . . . . . . . .",
			". Z . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"b b b b b b b b b",
			"b B b b b b b b b",
			"w b b b b b b b b",
			"W w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "black owns top rows, white dominates below")

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = math.min(S.t2m_cap, math.floor(25 / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "25 black cells → moderate payout")
	end)

	it("Z surrounded by white ring has zero black territory, pays zero", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W W W . . .",
			". . . W Z W . . .",
			". . . W W W . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w W W W w w w",
			"w w w W B W w w w",
			"w w w W W W w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "Z blocked by white ring, all empty cells white-influenced")

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		assert_player_plus_mult_delta(g, "black", snap, 0, "zero black territory pays zero plus_mult")
	end)

	it("Z with W cross blockade has zero territory, pays nothing", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . W . . . .",
			". . . W Z W . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		assert_player_plus_mult_delta(g, "black", snap, 0, "W cross blocks all Z influence → 0 territory → 0 payout")
	end)

	-- ── payout goes to territory owner at stone cell ──────────────────

	it("white z alone on empty board pays white plus_mult cap", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w W w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "sole white stone claims all territory")

		local snap = player_score_snapshot(g, "white")
		test_helper.finish_turn(g)

		local expected_delta = S.t2m_cap
		assert_player_plus_mult_delta(g, "white", snap, expected_delta, "white z pays white cap")
	end)

	it("Z and z on symmetric board each pay their respective side", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . z . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"b b b b b b b b b",
			"b b b b B b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			". . . . . . . . .",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w W w w w w",
			"w w w w w w w w w",
		}, "symmetric split with neutral row 5")

		local snap_black = player_score_snapshot(g, "black")
		local snap_white = player_score_snapshot(g, "white")
		test_helper.finish_turn(g)

		local expected_black = math.min(S.t2m_cap, math.floor(35 / S.t2m_divisor))
		local expected_white = math.min(S.t2m_cap, math.floor(35 / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap_black, expected_black, "Z pays black from 35 black cells")
		assert_player_plus_mult_delta(g, "white", snap_white, expected_white, "z pays white from 35 white cells")
	end)

	it("white z inside black ring enclosure gets zero white territory, pays nothing", function()
		set_board(g, {
			". . . . . . . . .",
			". . . B B B B . .",
			". . . B . . B . .",
			". . . B . z B . .",
			". . . B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local territory_white = test_helper.count_territory_cells(g, "white")
		local snap = player_score_snapshot(g, "white")
		test_helper.finish_turn(g)

		local expected_delta = math.min(S.t2m_cap, math.floor(territory_white / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "white", snap, expected_delta, "z surrounded by B ring → white territory ≈ 0 → no payout")
	end)

	-- ── captured stone stops paying ───────────────────────────────────

	it("captured Z pays nothing at end of turn", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . B . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.capture_stone_at(g, 6, 5, "black")
		test_helper.assert_board_cell_empty(g, 6, 5, "Z removed from board")

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		assert_player_plus_mult_delta(g, "black", snap, 0, "captured Z pays nothing")
	end)

	it("Z pays turn 1, captured before turn 2 pays nothing on second", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_t1 = S.t2m_cap
		assert_player_plus_mult_delta(g, "black", snap, expected_t1, "first turn payout at cap")

		test_helper.capture_stone_at(g, 5, 5, "black")
		local snap2 = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		assert_player_plus_mult_delta(g, "black", snap2, 0, "captured Z silent on second turn")
	end)

	-- ── multiple stones ───────────────────────────────────────────────

	it("two Z stones on all-black board each pay cap independently", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = 2 * S.t2m_cap
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "two Z stones each pay cap = 2x cap total")
	end)

	it("two Z stones on moderate territory both use same territory total", function()
		set_board(g, {
			". . . . . . . . .",
			". Z . . . . . . .",
			". . Z . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local territory_black = test_helper.count_territory_cells(g, "black")
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local per_stone = math.min(S.t2m_cap, math.floor(territory_black / S.t2m_divisor))
		local expected_delta = 2 * per_stone
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "both stones share same territory count")
	end)

	-- ── multi-round payout tracking ───────────────────────────────────

	it("Z pays every end of turn while it remains on board", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_t1 = S.t2m_cap
		assert_player_plus_mult_delta(g, "black", snap, expected_t1, "turn 1 payout")

		local snap2 = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		assert_player_plus_mult_delta(g, "black", snap2, expected_t1, "turn 2 payout identical")
	end)

	it("opponent places W stones, black territory shrinks, plus_mult decreases", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local territory_t1 = test_helper.count_territory_cells(g, "black")
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local payout_t1 = math.min(S.t2m_cap, math.floor(territory_t1 / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap, payout_t1, "turn 1 full board plus_mult")

		test_helper.place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local territory_t2 = test_helper.count_territory_cells(g, "black")
		local snap2 = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local payout_t2 = math.min(S.t2m_cap, math.floor(territory_t2 / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap2, payout_t2, "turn 2 plus_mult from reduced territory")
		assert.is_true(territory_t2 < territory_t1, "territory shrunk after opponent W placed")
	end)

	it("multiple W placements progressively shrink black territory and plus_mult", function()
		set_board(g, {
			". . . . . . . . .",
			". Z . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local territory_t1 = test_helper.count_territory_cells(g, "black")
		local snap1 = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local payout_t1 = math.min(S.t2m_cap, math.floor(territory_t1 / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap1, payout_t1, "turn 1 full board")

		test_helper.place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". B . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local territory_t2 = test_helper.count_territory_cells(g, "black")
		local snap2 = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local payout_t2 = math.min(S.t2m_cap, math.floor(territory_t2 / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap2, payout_t2, "turn 2 with one W")

		set_hand(g, "black", { "stone_basic" })
		place_stone(g, {
			". . . . . . . . .",
			". B . . . . . . .",
			". B . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". B . . . . . . .",
			". B . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
		})

		local territory_t3 = test_helper.count_territory_cells(g, "black")
		local snap3 = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local payout_t3 = math.min(S.t2m_cap, math.floor(territory_t3 / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap3, payout_t3, "turn 3 with two W")
		assert.is_true(territory_t3 < territory_t2, "territory further reduced")
	end)

	-- ── enclosure and influence territory ─────────────────────────────

	it("Z on ring enclosure board with corner W gets plus_mult from combined territory", function()
		set_board(g, {
			"W . . . . . . . W",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B . B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"W . . . Z . . . W",
		})
		assert_territory_ascii(g, {
			"W w w b b b w w W",
			"w w b b b b b w w",
			"w b b B B B b b w",
			". b b B b B b b .",
			"b b b B B B b b b",
			"w b b b b b b b w",
			"w w b b b b b w w",
			"w w . b b b . w w",
			"W w . b B b . w W",
		}, "enclosure at ring center + Z near bottom edge, corners split influence")

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = math.min(S.t2m_cap, math.floor(40 / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "40 black cells from enclosure + influence")
	end)

	it("Z in small black enclosure amid heavy white presence gets tiny plus_mult", function()
		set_board(g, {
			"W W W W W W W W W",
			"W . . . . . . . W",
			"W . . B B B . . W",
			"W . . B Z B . . W",
			"W . . B B B . . W",
			"W . . . . . . . W",
			"W . . . . . . . W",
			"W . . . . . . . W",
			"W W W W W W W W W",
		})

		local territory_black = test_helper.count_territory_cells(g, "black")
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = math.min(S.t2m_cap, math.floor(territory_black / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "small enclosure in white sea pays small plus_mult")
	end)

	it("Z on case 04 contested board with neutral cells counts only actual territory", function()
		set_board(g, {
			"B B . . W . . . .",
			"B . . W . . . . .",
			". W W . . . . . .",
			"W W . . . Z . . .",
			". . . . W W . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"B B w w W w w w w",
			"B w w W w w w w w",
			"w W W w w b b b b",
			"W W w w . B b b b",
			"w w w . W W w w w",
			"w . b B . w w w w",
			"w . b b . w w w w",
			"w . b b . w w w w",
			"w . b b . w w w w",
		}, "neutral cells at (4,5), Z replaces B at (4,6)")

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = math.min(S.t2m_cap, math.floor(14 / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "14 black cells, neutral excluded")
	end)

	it("Z on multi-enclosure board (case 05) pays from complex territory", function()
		set_board(g, {
			". . . W . . W . .",
			". B . W . . W . .",
			"B . W B B B W . .",
			". W B W . W B W B",
			". W B . W . B W .",
			". . W B B B . W .",
			". B . W . Z . W .",
			"W W W . . . . . W",
			". . . . . . . . .",
		})

		local territory_black = test_helper.count_territory_cells(g, "black")
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = math.min(S.t2m_cap, math.floor(territory_black / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "complex multi-enclosure territory drives plus_mult")
	end)

	it("Z behind white wall cutting the board gets small territory from rows above", function()
		set_board(g, {
			". . . . . . . . .",
			". . . Z . . . . .",
			". . . . . . . . .",
			"W W W W W W W W W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local territory_black = test_helper.count_territory_cells(g, "black")
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = math.min(S.t2m_cap, math.floor(territory_black / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "white wall cuts board, Z only gets rows above")
	end)

	-- ── edge and corner placement ─────────────────────────────────────

	it("Z at corner (1,1) still triggers plus_mult from territory", function()
		set_board(g, {
			"Z . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = S.t2m_cap
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "corner Z owns all 80 cells, hits cap")
	end)

	it("Z at edge (1,5) with W at opposite corner splits territory", function()
		set_board(g, {
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
		})

		local territory_black = test_helper.count_territory_cells(g, "black")
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		local expected_delta = math.min(S.t2m_cap, math.floor(territory_black / S.t2m_divisor))
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "edge Z pays from partial territory")
	end)

	-- ── plus_mult only — no points side effect ────────────────────────

	it("Z does not add points, only plus_mult", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)

		assert_player_points_unchanged(g, "black", snap, "Z does not add points, only plus_mult")
	end)

	-- ── no placement trigger ──────────────────────────────────────────

	it("Z plus_mult is not applied at placement, only at end of turn", function()
		set_hand(g, "black", { "territory_to_multiplier_stone" })
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

		local snap_before = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . Z . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, false)

		assert_player_plus_mult_delta(g, "black", snap_before, 0, "no plus_mult at placement time")

		test_helper.finish_turn(g)

		local expected_delta = S.t2m_cap
		assert_player_plus_mult_delta(g, "black", snap_before, expected_delta, "plus_mult added only after end of turn")
	end)
end)
