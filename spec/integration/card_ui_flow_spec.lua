local helper = require("spec.test_helper")

helper.install_love_test_stubs()
helper.reset_module("main")

local game = require("game")
local layout_mod = require("layout")
local match_state = require("match_state")
local board = require("board")
local config = require("config")

local function hand_click_point(layout, card_count, target_index)
	local slots = layout_mod.hand_fan_slots(layout, card_count)
	local slot = slots[target_index]
	for dx = 1, math.floor(slot.w - 1), 2 do
		for dy = 1, math.floor(slot.h - 1), 2 do
			local px = slot.x + dx
			local py = slot.y + dy
			if layout_mod.hand_index_at(layout, px, py, card_count) == target_index then
				return px, py
			end
		end
	end
	error("No clickable point for hand index " .. tostring(target_index))
end

local function hand_press(layout, card_count, target_index)
	local px, py = hand_click_point(layout, card_count, target_index)
	love.mousepressed(px, py, 1)
end

local function wire_play_handlers(layout, match)
	helper.set_upvalue(love.mousepressed, "screen", "play")
	helper.set_upvalue(love.mousepressed, "layout", layout)
	helper.set_upvalue(love.mousepressed, "match", match)
	helper.set_upvalue(love.mousepressed, "popup_state", { mode = "none", stones = {} })
	helper.set_upvalue(love.mousepressed, "stone_drag", { active = false })
	helper.set_upvalue(love.mousemoved, "screen", "play")
	helper.set_upvalue(love.mousemoved, "layout", layout)
	helper.set_upvalue(love.mousemoved, "match", match)
	helper.set_upvalue(love.mousereleased, "screen", "play")
	helper.set_upvalue(love.mousereleased, "layout", layout)
	helper.set_upvalue(love.mousereleased, "match", match)
	helper.set_upvalue(love.mousereleased, "stone_drag", { active = false })
end

local function setup_play_state()
	love.load()
	local width, height = love.graphics.getDimensions()
	local layout = layout_mod.from_window(width, height)
	local match = game.new("pvp")
	wire_play_handlers(layout, match)
	return layout, match
end

local function card_ui_state()
	return helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
end

describe("Card UI flow", function()
	it("clicking any card pops it and does not auto-play", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_point_tap", "card_small_mult" }
		player.cards.discard.ids = {}
		local count = #player.cards.hand.ids
		local p1x, p1y = hand_click_point(layout, count, 1)
		local p2x, p2y = hand_click_point(layout, count, 2)
		love.mousepressed(p1x, p1y, 1)
		local card_ui = card_ui_state()
		assert.are.equal(1, card_ui.selected_index)
		assert.are.equal(2, #player.cards.hand.ids)
		assert.are.equal(0, #player.cards.discard.ids)
		love.mousepressed(p2x, p2y, 1)
		assert.are.equal(2, card_ui.selected_index)
	end)

	it("Sale Prep uses Use then Confirm with two popup discard targets", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult" }
		player.cards.discard.ids = {}
		local count = #player.cards.hand.ids
		hand_press(layout, count, 1)
		local card_ui = card_ui_state()
		assert.are.equal("Use", card_ui.action_button_label)
		assert.is_true(card_ui.can_use)
		local use = layout_mod.card_use_button_rect(layout)
		love.mousepressed(use.x + 2, use.y + 2, 1)
		assert.are.equal("armed", card_ui.hand_target_phase)
		assert.is_nil(card_ui.selected_index)
		assert.are.equal("Confirm", card_ui.action_button_label)
		assert.is_false(card_ui.can_use)
		hand_press(layout, count, 2)
		hand_press(layout, count, 3)
		assert.is_true(card_ui.can_use)
		assert.is_true(card_ui.popped_target_indices[2])
		assert.is_true(card_ui.popped_target_indices[3])
		assert.is_nil(card_ui.popped_target_indices[1])
		assert.is_nil(card_ui.card_target_hint_indices[2])
		love.mousepressed(use.x + 2, use.y + 2, 1)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.are.equal(3, #player.cards.discard.ids)
	end)

	it("Sale Prep drag to Use arms then drag to Confirm commits", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult" }
		player.cards.discard.ids = {}
		local count = #player.cards.hand.ids
		hand_press(layout, count, 1)
		local use = layout_mod.card_use_button_rect(layout)
		love.mousemoved(use.x + use.w * 0.5, use.y + use.h * 0.5)
		love.mousereleased(use.x + use.w * 0.5, use.y + use.h * 0.5, 1)
		local card_ui = card_ui_state()
		assert.are.equal("armed", card_ui.hand_target_phase)
		hand_press(layout, count, 2)
		hand_press(layout, count, 3)
		love.mousepressed(use.x + 2, use.y + 2, 1)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.are.equal(3, #player.cards.discard.ids)
	end)

	it("Sale Prep blocks third target and keeps Confirm disabled until two picked", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult", "card_heal_1" }
		player.cards.discard.ids = {}
		local count = #player.cards.hand.ids
		hand_press(layout, count, 1)
		local use = layout_mod.card_use_button_rect(layout)
		love.mousepressed(use.x + 2, use.y + 2, 1)
		local card_ui = card_ui_state()
		assert.is_false(card_ui.can_use)
		hand_press(layout, count, 2)
		hand_press(layout, count, 3)
		assert.is_true(card_ui.can_use)
		hand_press(layout, count, 4)
		assert.are.equal(2, #card_ui.selected_targets)
		assert.are.equal("Target limit reached", card_ui.status_text)
		assert.is_true(card_ui.can_use)
	end)

	it("heal card stays disabled until damaged own stone target selected", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_heal_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		match.board[4][5] = board.make_stone(config.STONE_BLACK, "stone_basic", 3)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]
		love.mousepressed(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)
		love.mousereleased(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)
		local card_ui = card_ui_state()
		assert.is_false(card_ui.can_use)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 5)
		love.mousepressed(px, py, 1)
		assert.is_true(card_ui.can_use)
	end)

	it("invalid target click stores visible invalid feedback state", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_heal_1" }
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		love.mousepressed(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, 1)
		love.mousereleased(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, 1)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousepressed(px, py, 1)
		local card_ui = card_ui_state()
		assert.are.equal(0, #card_ui.selected_targets)
		assert.is_false(card_ui.can_use)
		assert.are.equal("Invalid target: missing required tags", card_ui.status_text)
		assert.is_not_nil(card_ui.invalid_target_feedback)
		assert.are.equal("stone", card_ui.invalid_target_feedback.object_type)
	end)

	it("attack click only pops then Confirm commits with board target", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		match.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 4)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		love.mousepressed(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, 1)
		local card_ui = card_ui_state()
		assert.are.equal(1, #player.cards.hand.ids)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousepressed(px, py, 1)
		assert.is_true(card_ui.can_use)
		local use = layout_mod.card_use_button_rect(layout)
		love.mousepressed(use.x + 2, use.y + 2, 1)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.are.equal(1, #player.cards.discard.ids)
	end)

	it("stone-target drag keeps popup and arrow from focus center", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		match.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 4)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]
		love.mousepressed(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)
		local fx, fy = layout_mod.card_focus_center(layout, 1, 1)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousemoved(px, py)
		local card_ui = card_ui_state()
		assert.are.equal("target_arrow", card_ui.drag_mode)
		assert.is_true(card_ui.drag_target_valid)
		assert.are.equal(1, card_ui.selected_index)
		assert.are.near(fx, card_ui.drag_arrow_from_x, 2)
		assert.are.near(fy, card_ui.drag_arrow_from_y, 2)
	end)

	it("attack valid arrow drop commits play", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 4)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		love.mousepressed(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, 1)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousemoved(px, py)
		love.mousereleased(px, py, 1)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.is_true(match.board[4][4].solidity < 4)
	end)

	it("attack card drag to invalid own stone cancels play", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		local hand_before = #player.cards.hand.ids
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		love.mousepressed(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, 1)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousemoved(px, py)
		local card_ui = card_ui_state()
		assert.is_false(card_ui.drag_target_valid)
		love.mousereleased(px, py, 1)
		assert.are.equal(hand_before, #player.cards.hand.ids)
		assert.are.equal(1, card_ui.selected_index)
		assert.are.equal(4, match.board[4][4].solidity)
	end)

	it("heal card drag validity changes and valid drop commits", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_heal_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		match.board[4][5] = board.make_stone(config.STONE_BLACK, "stone_basic", 3)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		love.mousepressed(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, 1)
		local full_x, full_y = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousemoved(full_x, full_y)
		local card_ui = card_ui_state()
		assert.is_false(card_ui.drag_target_valid)
		local dmg_x, dmg_y = layout_mod.grid_to_pixel(layout, 4, 5)
		love.mousemoved(dmg_x, dmg_y)
		assert.is_true(card_ui.drag_target_valid)
		love.mousereleased(dmg_x, dmg_y, 1)
		assert.are.equal(4, match.board[4][5].solidity)
		assert.are.equal(1, #player.cards.discard.ids)
	end)

	it("instant card drag to Confirm commits", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_point_tap" }
		player.cards.discard.ids = {}
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		love.mousepressed(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, 1)
		local use = layout_mod.card_use_button_rect(layout)
		love.mousemoved(use.x + use.w * 0.5, use.y + use.h * 0.5)
		love.mousereleased(use.x + use.w * 0.5, use.y + use.h * 0.5, 1)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.are.equal(1, #player.cards.discard.ids)
	end)

	it("hand hit-test prefers topmost overlapped card", function()
		local width, height = love.graphics.getDimensions()
		local layout = layout_mod.from_window(width, height)
		local slots = layout_mod.hand_fan_slots(layout, 4)
		local overlap_x = slots[2].x + slots[2].w - 4
		local overlap_y = slots[2].y + slots[2].h * 0.5
		local hit = layout_mod.hand_index_at(layout, overlap_x, overlap_y, 4)
		assert.is_true(hit >= 2)
	end)
end)
