require("spec.test_helper")

local board = require("board")
local config = require("config")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local scripts = require("ai.turn.scripts")
local spec_helper = require("spec.spec_helper")

describe("ai.turn.scripts", function()
	it("always includes skip_card", function()
		local g = match_state.new_match("pvc")
		g.phase = "MAIN_PHASE"
		g.to_play = "white"
		local view = match_view.for_bot(g)
		local list = scripts.enumerate(view, 12)
		local found = false
		for i = 1, #list do
			if list[i].script_id == "skip_card" then
				found = true
			end
		end
		assert.is_true(found)
	end)

	it("includes play_card only when energy is sufficient", function()
		local g = match_state.new_match("pvc")
		g.phase = "MAIN_PHASE"
		g.to_play = "white"
		g.players.white.cards.hand.ids = { "card_point_tap" }
		g.players.white.resources.energy_current = 0
		local view = match_view.for_bot(g)
		local list = scripts.enumerate(view, 12)
		for i = 1, #list do
			assert.is_not.equal("play_card:1", list[i].script_id)
		end
		g.players.white.resources.energy_current = 2
		list = scripts.enumerate(view, 12)
		local found_play = false
		for i = 1, #list do
			if list[i].hand_index == 1 then
				found_play = true
			end
		end
		assert.is_true(found_play)
	end)

	it("targeting scripts only use enemy or friendly stones", function()
		local rows = {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". B . W . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}
		local b = spec_helper.parse_board_ascii(rows)
		local g = match_state.new_match("pvc")
		g.board = b
		g.phase = "MAIN_PHASE"
		g.to_play = "white"
		g.players.white.cards.hand.ids = { "card_destroy_enemy_stone" }
		g.players.white.resources.energy_current = 5
		local view = match_view.for_bot(g)
		local list = scripts.enumerate(view, 12)
		local enemy_only = true
		for i = 1, #list do
			if list[i].target then
				local cell = b[list[i].target.row][list[i].target.col]
				if cell.color ~= config.STONE_BLACK then
					enemy_only = false
				end
			end
		end
		assert.is_true(enemy_only)
		assert.is_true(#list >= 2)
	end)
end)
