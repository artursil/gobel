local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local board = require("board")
local config = require("config")
local game = require("game")
local match_state = require("match_state")
local helper = require("spec.spec_helper")

--- Stone letter mapping (B=black basic, W=white, special letters = special black kinds)
local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	C = { color = config.STONE_BLACK, kind = "stone_power" },
	F = { color = config.STONE_BLACK, kind = "stone_focus" },
	L = { color = config.STONE_BLACK, kind = "stone_lieutenant" },
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

test_helper.set_integration_debug_stone_letters(STONE_TO_LETTER)

--- Base state shared by all tests. Each test gets a fresh copy via before_each.
--- Uses "basic_stones" game type: empty poses, stone_basic only — fully deterministic scoring.
--- run_state is replaced with a fresh isolated table so tests don't share persistent counters.
local function new_base_state()
	local g = game.new("pvp", "basic_stones")
	g.run_state = { counters = {} }
	return g
end

--- State setup helpers ---

--- @param g table
--- @param color string
--- @param stone_ids table
local function set_hand(g, color, stone_ids)
	local player = match_state.player_for_color(g, color)
	player.stones.playable_stones = stone_ids
	player.stones.selected_stone = stone_ids[1]
	player.stones.selected_stone_index = 1
end

--- @param g table
--- @param color string
--- @param amount integer
local function set_energy(g, color, amount)
	match_state.player_for_color(g, color).resources.energy_current = amount
end

--- @param g table
--- @param color string
--- @param amount integer
local function set_money(g, color, amount)
	match_state.player_for_color(g, color).resources.money = amount
end

--- @param g table
--- @param color string
--- @param card_ids table
local function set_cards(g, color, card_ids)
	match_state.player_for_color(g, color).cards.hand.ids = card_ids
end

--- @param g table
--- @param color string
--- @param fixed table
--- @param swappable table
local function set_stances(g, color, fixed, swappable)
	local player = match_state.player_for_color(g, color)
	player.stances.fixed = fixed or {}
	player.stances.swappable = swappable or {}
end

--- Sets g.turn_number so that resolve_round computes the desired round_number.
--- round_number = floor(turn_number / 2) + 1
--- @param g table
--- @param round integer
local function set_round(g, round)
	g.turn_number = round == 1 and 1 or (round - 1) * 2
end

--- Seeds a run-persistent counter for both owners.
--- @param g table
--- @param key string  counter key, e.g. "persistent_flux_mult"
--- @param black_value integer
--- @param white_value integer
local function set_persistent_counter(g, key, black_value, white_value)
	g.run_state.counters[key] = { B = black_value or 0, W = white_value or 0 }
end

--- @param g table
--- @param rows table  ASCII board rows using LETTER_TO_STONE convention
local function set_board(g, rows)
	g.board = helper.parse_board_ascii_kinds(rows, LETTER_TO_STONE)
end

--- Action helpers ---

--- @param g table
--- @param hand_index integer
local function play_card(g, hand_index)
	test_helper.assert_legal_play_card(g, hand_index, "play_card hand index " .. hand_index)
end

--- @param g table
--- @param hand_indices table  ordered list of hand positions to play
local function play_cards(g, hand_indices)
	for _, idx in ipairs(hand_indices) do
		play_card(g, idx)
	end
end

--- Place a stone by diffing board_rows against the current board.
--- The new stone's kind is read from the ASCII board; selected_stone is updated accordingly.
--- @param g table
--- @param board_rows table  full 9-row ASCII board showing where the new stone sits
local function place_stone(g, board_rows)
	local new_board = helper.parse_board_ascii_kinds(board_rows, LETTER_TO_STONE)
	for r = 1, config.BOARD_SIZE do
		for c = 1, config.BOARD_SIZE do
			if board.is_empty(g.board[r][c]) and not board.is_empty(new_board[r][c]) then
				local player = match_state.player_for_color(g, g.to_play)
				player.stones.selected_stone = new_board[r][c].kind
				test_helper.assert_legal_player_move(g, r, c, "place_stone at row " .. r .. " col " .. c)
				test_helper.finish_ui_animations_for_turn(g)
				return
			end
		end
	end
	error("place_stone: no new stone found in board_rows compared to the current board")
end

--- @param g table
--- @param hand_index integer
--- @param board_rows table
local function play_card_and_stone(g, hand_index, board_rows)
	play_card(g, hand_index)
	place_stone(g, board_rows)
end

--- Tests ---

describe("Scoring visual spec", function()
	local g

	before_each(function()
		g = new_base_state()
	end)

	after_each(test_helper.visual_scoring_debug_after_each(function()
		return g
	end))

	it("case_01: card + basic stone at center owns full board, scores correctly", function()
		-- Setup
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

		local snap = test_helper.visual_score_snapshot(g)

		-- Act: play card_point_tap (+2 pts, costs 1 energy), then place stone_basic at center
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

		-- card_point_tap costs 1 energy; started at 3
		test_helper.assert_player_energy(g, "black", 2, "card_point_tap spends 1 energy")
		test_helper.assert_player_money(g, "black", 0, "black starts with no money")

		-- single black stone at center claims all 80 empty cells
		test_helper.assert_territory_ascii(g, {
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

		test_helper.assert_territory_values_ascii(g, {
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

		test_helper.assert_players_total_score(g, 352, 0, "turn 1 center stone full-board score")
		test_helper.assert_players_total_score_delta(g, snap, 352, 0, "score change from match start")
	end)

	it("persistent_flux round 1 basic stone: counter applied in full as mult", function()
		-- counter = 9, round 1, stone_basic (no special/wall tag)
		-- round 1: apply_run_persistent_counter_as_mult → plus_mult += 9
		-- delta = +9
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_basic" })
		set_round(g, 1)

		local snap = test_helper.visual_score_snapshot(g)

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

		test_helper.assert_players_plus_mult_delta(g, snap, 9, 0, "persistent_flux round 1 basic stone")
	end)

	it("persistent_flux round 1 special stone: counter incremented then applied in full", function()
		-- counter = 9, round 1, stone_special (tag: special) → counter becomes 12
		-- round 1: apply_run_persistent_counter_as_mult → plus_mult += 12
		-- delta = +12
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 1)

		local snap = test_helper.visual_score_snapshot(g)

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

		test_helper.assert_players_plus_mult_delta(g, snap, 12, 0, "persistent_flux round 1 special stone")
	end)

	it("persistent_flux round 3 wall stone: pending delta applied (negative)", function()
		-- counter = 9, round 3, stone_wall (tag: wall) → pending_delta = -3
		-- round >= 2: apply_run_persistent_pending_delta_as_mult → plus_mult += -3
		-- delta = -3
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_wall" })
		set_round(g, 3)

		local snap = test_helper.visual_score_snapshot(g)

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

		test_helper.assert_players_plus_mult_delta(g, snap, -3, 0, "persistent_flux round 3 wall stone counter 9")
	end)
	it("persistent_flux round 3 wall stone: pending delta applied (negative)", function()
		-- counter = 2, round 3, stone_wall (tag: wall) → pending_delta = -3
		-- round >= 2: apply_run_persistent_pending_delta_as_mult → plus_mult += -3
		-- delta = -2
		set_persistent_counter(g, "persistent_flux_mult", 2, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_wall" })
		set_round(g, 3)

		local snap = test_helper.visual_score_snapshot(g)

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

		test_helper.assert_players_plus_mult_delta(g, snap, -2, 0, "persistent_flux round 3 wall stone counter 2")
	end)

	it("persistent_flux round 4 special stone: pending delta applied (positive)", function()
		-- counter = 9, round 4, stone_special (tag: special) → pending_delta = +3
		-- round >= 2: apply_run_persistent_pending_delta_as_mult → plus_mult += 3
		-- delta = +3
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 4)

		local snap = test_helper.visual_score_snapshot(g)

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

		test_helper.assert_players_plus_mult_delta(g, snap, 3, 0, "persistent_flux round 4 special stone")
	end)

	it("blueprint + persistent_flux round 4 special stone: pending delta applied twice", function()
		-- counter = 9, round 4, stone_special (tag: special)
		-- blueprint (priority 5) fires first: copies persistent_flux effects inline
		--   → adjust counter: 9→12, pending=+3
		--   → apply pending delta: plus_mult += 3, pending cleared
		-- persistent_flux (priority 10/20) fires second:
		--   → adjust counter: 12→15, pending=+3
		--   → apply pending delta: plus_mult += 3, pending cleared
		-- total plus_mult added = 3 + 3 = 6, delta = +6
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_echo", "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 4)

		local snap = test_helper.visual_score_snapshot(g)

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

		test_helper.assert_players_plus_mult_delta(g, snap, 6, 0, "echo + persistent_flux double pending")
	end)
	it("2 x blueprint + persistent_flux round 4 special stone: pending delta applied twice", function()
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_echo", "stance_echo", "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 4)

		local snap = test_helper.visual_score_snapshot(g)

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

		test_helper.assert_players_plus_mult_delta(g, snap, 9, 0, "two echo + persistent_flux triple pending")
	end)
end)
