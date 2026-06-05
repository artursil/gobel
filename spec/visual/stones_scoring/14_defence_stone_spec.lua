--- Visual spec: defence_stone (OBJECTS.md #14).
---
--- Stone under test: defence_stone
--- Effect: on placement and while connected, adds defence_solidity_bonus to own stones
--- orthogonally and diagonally adjacent to the defence network.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local stone_solidity = require("objects.stone_solidity")
local S = require("spec.parameters_helper").stone

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	D = { color = config.STONE_BLACK, kind = "defence_stone" },
	d = { color = config.STONE_WHITE, kind = "defence_stone" },
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
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content

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

describe("defence_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "defence_stone" }, "defence_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("defence_stone solidity propagation", function()
		it("defence_stone scenario 1: isolated placement gains defence_solidity_bonus", function()
			set_hand(g, "black", { "defence_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_solidity = stone_solidity.stone_max_solidity("defence_stone") + S.defence_solidity_bonus
			assert.are.equal(expected_solidity, g.board[5][5].solidity, "defence stone boosts itself")
		end)

		it("defence_stone scenario 2: orthogonal neighbors gain defence_solidity_bonus", function()
			set_hand(g, "black", { "defence_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B B . . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_solidity = stone_solidity.stone_max_solidity("stone_basic") + S.defence_solidity_bonus
			assert.are.equal(expected_solidity, g.board[4][5].solidity, "orthogonal basic +1")
			assert.are.equal(expected_solidity, g.board[4][6].solidity, "orthogonal basic +1")
		end)

		it("defence_stone scenario 3: diagonal neighbors gain defence_solidity_bonus", function()
			set_hand(g, "black", { "defence_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . B . . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_solidity = stone_solidity.stone_max_solidity("stone_basic") + S.defence_solidity_bonus
			assert.are.equal(expected_solidity, g.board[3][4].solidity, "diagonal neighbor +1")
			assert.are.equal(expected_solidity, g.board[3][6].solidity, "diagonal neighbor +1")
		end)

		it("defence_stone scenario 4: later adjacent own stone receives defence_solidity_bonus", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			set_hand(g, "black", { "stone_basic" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B B . . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_solidity = stone_solidity.stone_max_solidity("stone_basic") + S.defence_solidity_bonus
			assert.are.equal(expected_solidity, g.board[4][6].solidity, "new connection inherits defence bonus")
		end)

		it("defence_stone scenario 5: disconnected stone loses live-linked bonus", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B D . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.capture_stone_at(g, 4, 6, "white")
			local expected_solidity = stone_solidity.stone_max_solidity("stone_basic")
			assert.are.equal(expected_solidity, g.board[4][5].solidity, "captured link removes bonus")
		end)

		it("defence_stone scenario 6: two defence sources stack to double bonus", function()
			set_hand(g, "black", { "defence_stone", "defence_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . D B D . . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local expected_solidity = stone_solidity.stone_max_solidity("stone_basic") + S.defence_solidity_bonus * 2
			assert.are.equal(expected_solidity, g.board[4][5].solidity, "overlap stone +2 from two defence sources")
		end)

		it("defence_stone scenario 7: black defence does not buff white stones", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			set_hand(g, "black", { "defence_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_white = stone_solidity.stone_max_solidity("stone_basic")
			local expected_black = stone_solidity.stone_max_solidity("defence_stone") + S.defence_solidity_bonus
			assert.are.equal(expected_white, g.board[4][4].solidity, "white stone not buffed by black defence")
			assert.are.equal(expected_black, g.board[4][5].solidity, "black defence buffs black only")
		end)

		it("defence_stone scenario 8: removed defence source drops its bonus", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B D . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.capture_stone_at(g, 4, 6, "white")
			test_helper.finish_turn(g)
			local expected_solidity = stone_solidity.stone_max_solidity("stone_basic")
			assert.are.equal(expected_solidity, g.board[4][5].solidity, "bonus from removed defence gone")
		end)

		it("defence_stone scenario 9: edge layout keeps in-bounds propagation", function()
			set_hand(g, "black", { "defence_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"B . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"B D . . . . . . .",
				". . . . . . . . .",
			})
			local expected_solidity = stone_solidity.stone_max_solidity("stone_basic") + S.defence_solidity_bonus
			assert.are.equal(expected_solidity, g.board[8][1].solidity, "edge neighbour buffed")
		end)

		it("defence_stone scenario 10: defended stone has higher solidity than undefended neighbor", function()
			set_hand(g, "black", { "defence_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . . B . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local base_solidity = stone_solidity.stone_max_solidity("stone_basic")
			local expected_defended = base_solidity + S.defence_solidity_bonus
			local expected_undefended = base_solidity
			assert.are.equal(expected_defended, g.board[4][4].solidity, "stone beside defence gains bonus solidity")
			assert.are.equal(expected_undefended, g.board[4][7].solidity, "remote neighbor keeps base solidity")
		end)

		it("defence_stone scenario 11: white defence buffs white stones only", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.place_stone_for(g, "white", "defence_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B d . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_black = stone_solidity.stone_max_solidity("stone_basic")
			local expected_white = stone_solidity.stone_max_solidity("defence_stone") + S.defence_solidity_bonus
			assert.are.equal(expected_black, g.board[4][4].solidity, "black stone not buffed by white defence")
			assert.are.equal(expected_white, g.board[4][5].solidity, "white defence buffs white defence stone")
		end)

		it("defence_stone scenario 12: remote own stone without connection keeps base solidity", function()
			set_hand(g, "black", { "defence_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"B . . . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"B . . . . . B . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_solidity = stone_solidity.stone_max_solidity("stone_basic")
			assert.are.equal(expected_solidity, g.board[4][7].solidity, "disconnected stone keeps base solidity")
		end)

		it("defence_stone scenario 13: adjacent defence stones buff each other", function()
			set_hand(g, "black", { "defence_stone", "defence_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . D . . . .",
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
				". . . . D D . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local base = stone_solidity.stone_max_solidity("defence_stone")
			local expected_first = base + S.defence_solidity_bonus
			local expected_second = base + S.defence_solidity_bonus
			assert.are.equal(expected_first, g.board[5][5].solidity, "first defence stone buffed by neighbor")
			assert.are.equal(expected_second, g.board[5][6].solidity, "second defence stone buffed by neighbor")
		end)

		it("defence_stone scenario 14: damaged connected stone receives bonus on current solidity", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			g.board[4][5].solidity = stone_solidity.stone_max_solidity("stone_basic") - 1
			set_hand(g, "black", { "defence_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . D . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_solidity = stone_solidity.stone_max_solidity("stone_basic") - 1 + S.defence_solidity_bonus
			assert.are.equal(expected_solidity, g.board[4][5].solidity, "damaged stone gains bonus on current solidity")
		end)

		it("defence_stone scenario 15: corner defence buffs only in-bounds neighbors", function()
			set_hand(g, "black", { "defence_stone" })
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
			place_stone(g, {
				"D B . . . . . . .",
				"B . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local base = stone_solidity.stone_max_solidity("stone_basic")
			local expected_defence = stone_solidity.stone_max_solidity("defence_stone") + S.defence_solidity_bonus
			local expected_neighbor = base + S.defence_solidity_bonus
			assert.are.equal(expected_defence, g.board[1][1].solidity, "corner defence buffs itself")
			assert.are.equal(expected_neighbor, g.board[1][2].solidity, "orthogonal corner neighbor buffed")
			assert.are.equal(expected_neighbor, g.board[2][1].solidity, "orthogonal corner neighbor buffed")
		end)
	end)
end)
