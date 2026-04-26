local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local board = require("board")
local config = require("config")
local content = require("content")
local game = require("game")
local layout_mod = require("layout")
helper.reset_module("main")
local match_state = require("match_state")
local render = require("render")
local rules = require("rules")

local function get_popup_state()
	local handler = helper.get_upvalue(love.mousepressed, "handle_active_popup_click")
	return helper.get_upvalue(handler, "popup_state")
end

local function setup_play_state()
	love.load()
	local width, height = love.graphics.getDimensions()
	local layout = layout_mod.from_window(width, height)
	local match = game.new("pvp")
	helper.set_upvalue(love.mousepressed, "screen", "play")
	helper.set_upvalue(love.mousepressed, "layout", layout)
	helper.set_upvalue(love.mousepressed, "match", match)
	local popup = {
		mode = "none",
		stone_id = nil,
		stones = {},
		focus_index = nil,
		anchor_rect = nil,
		selected_slot = nil,
	}
	local active_handler = helper.get_upvalue(love.mousepressed, "handle_active_popup_click")
	local open_handler = helper.get_upvalue(love.mousepressed, "handle_open_popup_click")
	helper.set_upvalue(active_handler, "popup_state", popup)
	helper.set_upvalue(active_handler, "layout", layout)
	helper.set_upvalue(open_handler, "layout", layout)
	helper.set_upvalue(love.mousepressed, "stone_drag", {
		active = false,
		stone_id = nil,
		source_index = nil,
		start_x = 0,
		start_y = 0,
		current_x = 0,
		current_y = 0,
		moved = false,
	})
	helper.set_upvalue(love.mousepressed, "card_ui", {
		selected_index = nil,
		drag_active = false,
		drag_index = nil,
		start_x = 0,
		start_y = 0,
		current_x = 0,
		current_y = 0,
		moved = false,
	})
	helper.set_upvalue(love.mousereleased, "screen", "play")
	helper.set_upvalue(love.mousereleased, "layout", layout)
	helper.set_upvalue(love.mousereleased, "match", match)
	helper.set_upvalue(love.mousereleased, "popup_state", helper.get_upvalue(love.mousepressed, "popup_state"))
	helper.set_upvalue(love.mousereleased, "stone_drag", helper.get_upvalue(love.mousepressed, "stone_drag"))
	helper.set_upvalue(love.mousereleased, "card_ui", helper.get_upvalue(love.mousepressed, "card_ui"))
	helper.set_upvalue(love.keypressed, "screen", "play")
	helper.set_upvalue(love.keypressed, "match", match)
	return layout, match, popup
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
		local popup_state = get_popup_state()
		assert.are.equal("selector-details", popup_state.mode)
		assert.is_true(type(popup_state.stone_id) == "string")

		love.keypressed("escape")
		popup_state = get_popup_state()
		assert.are.equal("none", popup_state.mode)
	end)

	it("pouch popup shows remaining stones grid and detail focus updates on tile click", function()
		local layout, match = setup_play_state()
		local active = match_state.player_for_color(match, match.to_play)
		local px = layout.pouch_panel.x + 8
		local py = layout.pouch_panel.y + 8
		love.mousepressed(px, py, 1)

		local popup_state = get_popup_state()
		assert.are.equal("pouch-browser", popup_state.mode)
		assert.are.equal(#active.stones.pouch.ids, #popup_state.stones)

		if #popup_state.stones >= 2 then
			local rects = layout_mod.pouch_popup_grid_rects(layout, #popup_state.stones)
			local r = rects[2]
			love.mousepressed(r.x + 2, r.y + 2, 1)
			popup_state = get_popup_state()
			assert.are.equal(2, popup_state.focus_index)
			local stone = content.get_stone(popup_state.stones[popup_state.focus_index])
			assert.is_true(type(stone.name) == "string" and #stone.name > 0)
			assert.is_true(type(stone.description) == "string" and #stone.description > 0)
		end

		local close = layout_mod.popup_close_rect(layout)
		love.mousepressed(close.x + 2, close.y + 2, 1)
		popup_state = get_popup_state()
		assert.are.equal("none", popup_state.mode)
	end)

	it("deck popup opens from deck panel and supports deck/played focus selection", function()
		local layout, match = setup_play_state()
		local active = match_state.player_for_color(match, match.to_play)
		love.mousepressed(layout.deck_panel.x + 8, layout.deck_panel.y + 8, 1)

		local popup_state = get_popup_state()
		assert.are.equal("deck-browser", popup_state.mode)
		assert.are.equal(#active.cards.deck.ids, #popup_state.cards)
		assert.are.equal(#active.cards.discard.ids, #popup_state.played_cards)

		if #popup_state.cards > 0 then
			local deck_rects = layout_mod.pouch_popup_grid_rects(layout, #popup_state.cards)
			local first = deck_rects[1]
			love.mousepressed(first.x + 2, first.y + 2, 1)
			popup_state = get_popup_state()
			assert.are.equal("deck", popup_state.focus_group)
			assert.are.equal(1, popup_state.focus_index)
		end

		table.insert(active.cards.discard.ids, "card_point_tap")
		active.cards.deck.ids = {}
		local close_before_refresh = layout_mod.popup_close_rect(layout)
		love.mousepressed(close_before_refresh.x + 2, close_before_refresh.y + 2, 1)
		love.mousepressed(layout.deck_panel.x + 8, layout.deck_panel.y + 8, 1)
		popup_state = get_popup_state()
		local box = layout.popup
		local cols = 5
		local gap = 8
		local pad = 16
		local chip = math.floor((box.w - pad * 2 - gap * (cols - 1)) / cols)
		chip = math.max(56, math.min(78, chip))
		local played_y = box.y + 52 + 160
		love.mousepressed(box.x + pad + 2, played_y + 2, 1)
		popup_state = get_popup_state()
		assert.are.equal("played", popup_state.focus_group)
		assert.are.equal(1, popup_state.focus_index)

		local close = layout_mod.popup_close_rect(layout)
		love.mousepressed(close.x + 2, close.y + 2, 1)
		popup_state = get_popup_state()
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
