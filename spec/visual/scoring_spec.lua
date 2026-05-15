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
	X = { color = config.STONE_BLACK, kind = "stone_wall" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	if def.color == config.STONE_BLACK then
		STONE_TO_LETTER[def.kind] = letter
	end
end

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
	assert.is_true(game.play_card(g, hand_index))
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
				assert.is_true(game.player_move(g, r, c))
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

--- Score snapshot ---

--- Captures a lightweight snapshot of both players' scores and resources.
--- @param g table
--- @return table
local function snapshot(g)
	local function snap_player(p)
		return {
			total = p.score.total,
			points = p.score.points,
			territory = p.score.territory,
			plus_mult = p.score.plus_mult,
			energy = p.resources.energy_current,
			money = p.resources.money,
		}
	end
	return {
		black = snap_player(g.players.black),
		white = snap_player(g.players.white),
	}
end

--- Territory value board rendering ---

--- Renders: # = stone, 1 = black-owned empty, 2 = white-owned empty, 0 = neutral.
--- @param g table
--- @return string
local function territory_value_ascii(g)
	local territory = g.territory or helper.territory_map(g.board, "regional")
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			if not board.is_empty(g.board[r][c]) then
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

--- Assert helpers ---

--- @param g table
--- @param color string
--- @param expected integer
local function assert_energy(g, color, expected)
	assert.are.equal(expected, match_state.player_for_color(g, color).resources.energy_current)
end

--- @param g table
--- @param color string
--- @param expected integer
local function assert_money(g, color, expected)
	assert.are.equal(expected, match_state.player_for_color(g, color).resources.money)
end

--- Asserts territory ownership grid against expected ASCII rows (B/W=stone, b/w=owned empty, .=neutral).
--- @param g table
--- @param expected_rows table
local function assert_territory(g, expected_rows)
	local territory = g.territory or helper.territory_map(g.board, "regional")
	assert.are.equal(table.concat(expected_rows, "\n"), helper.territory_ascii(g.board, territory))
end

--- Asserts territory value board against expected ASCII rows (#=stone, 1=black, 2=white, 0=neutral).
--- @param g table
--- @param expected_rows table
local function assert_territory_values(g, expected_rows)
	assert.are.equal(table.concat(expected_rows, "\n"), territory_value_ascii(g))
end

--- Asserts both players' total scores.
--- @param g table
--- @param expected_black integer
--- @param expected_white integer
local function assert_scores(g, expected_black, expected_white)
	assert.are.equal(expected_black, g.players.black.score.total)
	assert.are.equal(expected_white, g.players.white.score.total)
end

--- Asserts how much each player's total score changed relative to a snapshot.
--- @param g table
--- @param snap table  result of snapshot(g) taken before the action
--- @param expected_delta_black integer
--- @param expected_delta_white integer
local function assert_score_delta(g, snap, expected_delta_black, expected_delta_white)
	assert.are.equal(expected_delta_black, g.players.black.score.total - snap.black.total)
	assert.are.equal(expected_delta_white, g.players.white.score.total - snap.white.total)
end

--- Asserts how much each player's plus_mult changed relative to a snapshot.
--- @param g table
--- @param snap table  result of snapshot(g) taken before the action
--- @param expected_delta_black integer
--- @param expected_delta_white integer
local function assert_mult_delta(g, snap, expected_delta_black, expected_delta_white)
	assert.are.equal(expected_delta_black, g.players.black.score.plus_mult - snap.black.plus_mult)
	assert.are.equal(expected_delta_white, g.players.white.score.plus_mult - snap.white.plus_mult)
end

--- Tests ---

describe("Scoring visual spec", function()
	local g

	before_each(function()
		g = new_base_state()
	end)

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

		local snap = snapshot(g)

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
		assert_energy(g, "black", 2)
		assert_money(g, "black", 0)

		-- single black stone at center claims all 80 empty cells
		assert_territory(g, {
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

		-- no tower or doubled-territory effects, all owned empty cells count as 1
		assert_territory_values(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 # 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		})

		-- formula: turn_bonus * territory * points * plus_mult * x_mult
		-- black: 1.1 (turn 1) * 80 (territory) * 4 (starting 1 + stone_basic=1 + card_point_tap=2) * 1 * 1 = 352
		-- white: 1.1 * 0 * 1 * 1 * 1 = 0
		assert_scores(g, 352, 0)
		assert_score_delta(g, snap, 352, 0)
	end)

	it("persistent_flux round 1 basic stone: counter applied in full as mult", function()
		-- counter = 9, round 1, stone_basic (no special/wall tag)
		-- round 1: apply_run_persistent_counter_as_mult → plus_mult += 9
		-- delta = +9
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_basic" })
		set_round(g, 1)

		local snap = snapshot(g)

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

		assert_mult_delta(g, snap, 9, 0)
	end)

	it("persistent_flux round 1 special stone: counter incremented then applied in full", function()
		-- counter = 9, round 1, stone_special (tag: special) → counter becomes 12
		-- round 1: apply_run_persistent_counter_as_mult → plus_mult += 12
		-- delta = +12
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 1)

		local snap = snapshot(g)

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

		assert_mult_delta(g, snap, 12, 0)
	end)

	it("persistent_flux round 3 wall stone: pending delta applied (negative)", function()
		-- counter = 9, round 3, stone_wall (tag: wall) → pending_delta = -3
		-- round >= 2: apply_run_persistent_pending_delta_as_mult → plus_mult += -3
		-- delta = -3
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_wall" })
		set_round(g, 3)

		local snap = snapshot(g)

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

		assert_mult_delta(g, snap, -3, 0)
	end)
	it("persistent_flux round 3 wall stone: pending delta applied (negative)", function()
		-- counter = 2, round 3, stone_wall (tag: wall) → pending_delta = -3
		-- round >= 2: apply_run_persistent_pending_delta_as_mult → plus_mult += -3
		-- delta = -2
		set_persistent_counter(g, "persistent_flux_mult", 2, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_wall" })
		set_round(g, 3)

		local snap = snapshot(g)

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

		assert_mult_delta(g, snap, -2, 0)
	end)

	it("persistent_flux round 4 special stone: pending delta applied (positive)", function()
		-- counter = 9, round 4, stone_special (tag: special) → pending_delta = +3
		-- round >= 2: apply_run_persistent_pending_delta_as_mult → plus_mult += 3
		-- delta = +3
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 4)

		local snap = snapshot(g)

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

		assert_mult_delta(g, snap, 3, 0)
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

		local snap = snapshot(g)

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

		assert_mult_delta(g, snap, 6, 0)
	end)
	it("2 x blueprint + persistent_flux round 4 special stone: pending delta applied twice", function()
		set_persistent_counter(g, "persistent_flux_mult", 9, 0)
		set_stances(g, "black", { "stance_echo", "stance_echo", "stance_persistent_flux" }, {})
		set_hand(g, "black", { "stone_special" })
		set_round(g, 4)

		local snap = snapshot(g)

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

		assert_mult_delta(g, snap, 9, 0)
	end)
end)
