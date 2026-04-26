local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local board = require("board")
local config = require("config")
local content = require("content")
local game = require("game")
local layout_mod = require("layout")
local main_module = helper.reset_module("main")
local match_state = require("match_state")
local render = require("render")
local rules = require("rules")

local function setup_play_state()
	love.load()
	local width, height = love.graphics.getDimensions()
	love.mousepressed(width * 0.5, height * 0.5 - 30, 1)
	local layout = helper.get_upvalue(love.mousepressed, "layout")
	local match = helper.get_upvalue(love.mousepressed, "match")
	local popup_state = helper.get_upvalue(love.mousepressed, "popup_state")
	return layout, match, popup_state
end

local function chip_center(layout, index, total)
	local rect = layout_mod.stone_chip_rects(layout, total)[index]
	return rect.x + rect.w * 0.5, rect.y + rect.h * 0.5
end

describe("T-051 stone popup and interaction integration", function()
	it("selector click opens details popup and escape closes deterministically", function()
		local layout, match = setup_play_state()
		local active = match_state.player_for_color(match, match.to_play)
		local x, y = chip_center(layout, 1, #active.stones.playable_stones)

		love.mousepressed(x, y, 1)
		love.mousereleased(x, y, 1)
		local popup_state = helper.get_upvalue(love.mousepressed, "popup_state")
		assert.are.equal("selector-details", popup_state.mode)
		assert.is_true(type(popup_state.stone_id) == "string")

		love.keypressed("escape")
		popup_state = helper.get_upvalue(love.mousepressed, "popup_state")
		assert.are.equal("none", popup_state.mode)
	end)

	it("pouch popup shows remaining stones grid and detail focus updates on tile click", function()
		local layout, match = setup_play_state()
		local active = match_state.player_for_color(match, match.to_play)
		local px = layout.pouch_panel.x + 8
		local py = layout.pouch_panel.y + 8
		love.mousepressed(px, py, 1)

		local popup_state = helper.get_upvalue(love.mousepressed, "popup_state")
		assert.are.equal("pouch-browser", popup_state.mode)
		assert.are.equal(#active.stones.pouch.ids, #popup_state.stones)

		if #popup_state.stones >= 2 then
			local rects = layout_mod.pouch_popup_grid_rects(layout, #popup_state.stones)
			local r = rects[2]
			love.mousepressed(r.x + 2, r.y + 2, 1)
			popup_state = helper.get_upvalue(love.mousepressed, "popup_state")
			assert.are.equal(2, popup_state.focus_index)
			local stone = content.get_stone(popup_state.stones[popup_state.focus_index])
			assert.is_true(type(stone.name) == "string" and #stone.name > 0)
			assert.is_true(type(stone.description) == "string" and #stone.description > 0)
		end

		local close = layout_mod.popup_close_rect(layout)
		love.mousepressed(close.x + 2, close.y + 2, 1)
		popup_state = helper.get_upvalue(love.mousepressed, "popup_state")
		assert.are.equal("none", popup_state.mode)
	end)

	it("popup guard prevents board placement and card play while active", function()
		local layout, match = setup_play_state()
		local active = match_state.player_for_color(match, match.to_play)
		local hand_before = #active.cards.hand.ids
		local discard_before = #active.cards.discard.ids
		local board_before = board.clone(match.board)

		love.mousepressed(layout.pouch_panel.x + 8, layout.pouch_panel.y + 8, 1)

		local hand_rect = layout_mod.hand_card_rects(layout, #active.cards.hand.ids)[1]
		love.mousepressed(hand_rect.x + 2, hand_rect.y + 2, 1)
		local legal = rules.all_legal_moves(match.board, config.STONE_BLACK, match.ko_ban, active.stones.selected_stone)[1]
		local gx, gy = layout_mod.grid_to_pixel(layout, legal[1], legal[2])
		love.mousepressed(gx, gy, 1)

		assert.are.equal(hand_before, #active.cards.hand.ids)
		assert.are.equal(discard_before, #active.cards.discard.ids)
		assert.is_true(board.equal(board_before, match.board))
	end)

	it("core loop still works after popup open and close cycle", function()
		local layout, match = setup_play_state()
		local active = match_state.player_for_color(match, match.to_play)
		love.mousepressed(layout.pouch_panel.x + 8, layout.pouch_panel.y + 8, 1)
		local close = layout_mod.popup_close_rect(layout)
		love.mousepressed(close.x + 2, close.y + 2, 1)

		assert.is_true(game.play_card(match, 1))
		local selected = active.stones.playable_stones[1]
		assert.is_true(game.select_stone(match, selected))
		local legal = rules.all_legal_moves(match.board, config.STONE_BLACK, match.ko_ban, selected)[1]
		assert.is_true(game.player_move(match, legal[1], legal[2]))
		if match.phase == "MAIN_PHASE" then
			game.player_pass(match)
		end
		if match.phase == "MAIN_PHASE" then
			game.player_pass(match)
		end
		assert.is_true(match.ended)
		assert.are.equal("MATCH_END", match.phase)
	end)
end)
