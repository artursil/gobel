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

local function setup_play_state()
	love.load()
	local width, height = love.graphics.getDimensions()
	local layout = layout_mod.from_window(width, height)
	local match = game.new("pvp")
	local card_ui = {
		selected_index = nil,
		drag_active = false,
		drag_index = nil,
		start_x = 0,
		start_y = 0,
		current_x = 0,
		current_y = 0,
		moved = false,
	}
	helper.set_upvalue(love.mousepressed, "screen", "play")
	helper.set_upvalue(love.mousepressed, "layout", layout)
	helper.set_upvalue(love.mousepressed, "match", match)
	helper.set_upvalue(love.mousepressed, "popup_state", { mode = "none", stones = {} })
	helper.set_upvalue(love.mousepressed, "stone_drag", { active = false })
	helper.set_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui", card_ui)
	helper.set_upvalue(love.mousemoved, "card_ui", card_ui)
	helper.set_upvalue(love.mousereleased, "screen", "play")
	helper.set_upvalue(love.mousereleased, "layout", layout)
	helper.set_upvalue(love.mousereleased, "match", match)
	helper.set_upvalue(love.mousereleased, "stone_drag", { active = false })
	helper.set_upvalue(love.mousereleased, "card_ui", card_ui)
	helper.set_upvalue(love.mousepressed, "handle_card_press", helper.get_upvalue(love.mousepressed, "handle_card_press"))
	return layout, match
end

describe("Card UI flow", function()
	it("instant card plays immediately on click", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_point_tap" }
		player.cards.discard.ids = {}
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]
		love.mousepressed(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.are.equal(1, #player.cards.discard.ids)
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
		local card_ui = helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
		assert.is_false(card_ui.can_use)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 5)
		love.mousepressed(px, py, 1)
		assert.is_true(card_ui.can_use)
	end)

	it("money card stays disabled until exactly two own card targets selected", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult" }
		player.cards.discard.ids = {}
		local count = #player.cards.hand.ids
		local p1x, p1y = hand_click_point(layout, count, 1)
		local p2x, p2y = hand_click_point(layout, count, 2)
		local p3x, p3y = hand_click_point(layout, count, 3)
		love.mousepressed(p1x, p1y, 1)
		local card_ui = helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
		assert.is_false(card_ui.can_use)
		love.mousepressed(p2x, p2y, 1)
		assert.is_false(card_ui.can_use)
		love.mousepressed(p3x, p3y, 1)
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
		local card_ui = helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
		assert.are.equal(0, #card_ui.selected_targets)
		assert.is_false(card_ui.can_use)
		assert.are.equal("Invalid target: missing required tags", card_ui.status_text)
		assert.is_not_nil(card_ui.invalid_target_feedback)
		assert.are.equal("stone", card_ui.invalid_target_feedback.object_type)
	end)

	it("selected target chips remove targets and keep use synced", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult" }
		local count = #player.cards.hand.ids
		local p1x, p1y = hand_click_point(layout, count, 1)
		local p2x, p2y = hand_click_point(layout, count, 2)
		local p3x, p3y = hand_click_point(layout, count, 3)
		love.mousepressed(p1x, p1y, 1)
		love.mousepressed(p2x, p2y, 1)
		love.mousepressed(p3x, p3y, 1)
		local card_ui = helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
		assert.is_true(card_ui.can_use)
		assert.are.equal(2, #card_ui.target_chip_rects)
		local chip = card_ui.target_chip_rects[1]
		love.mousepressed(chip.x + 2, chip.y + 2, 1)
		assert.are.equal(1, #card_ui.selected_targets)
		assert.are.equal(1, #card_ui.target_chip_rects)
		assert.is_false(card_ui.can_use)
	end)

	it("multi-target selection cannot exceed max targets", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult", "card_heal_1" }
		local count = #player.cards.hand.ids
		local p1x, p1y = hand_click_point(layout, count, 1)
		local p2x, p2y = hand_click_point(layout, count, 2)
		local p3x, p3y = hand_click_point(layout, count, 3)
		local p4x, p4y = hand_click_point(layout, count, 4)
		love.mousepressed(p1x, p1y, 1)
		love.mousepressed(p2x, p2y, 1)
		love.mousepressed(p3x, p3y, 1)
		local card_ui = helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
		assert.are.equal(2, #card_ui.selected_targets)
		assert.is_true(card_ui.can_use)
		love.mousepressed(p4x, p4y, 1)
		assert.are.equal(2, #card_ui.selected_targets)
		assert.are.equal("Target limit reached", card_ui.status_text)
		assert.is_true(card_ui.can_use)
	end)

	it("selects a card on click and plays through Use button", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		match.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 4)
		local hand_before = #player.cards.hand.ids
		local discard_before = #player.cards.discard.ids

		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]
		love.mousepressed(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)
		love.mousereleased(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)

		local card_ui = helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
		assert.are.equal(1, card_ui.selected_index)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousepressed(px, py, 1)
		assert.is_true(card_ui.can_use)

		local use = layout_mod.card_use_button_rect(layout)
		love.mousepressed(use.x + 2, use.y + 2, 1)
		assert.are.equal(hand_before - 1, #player.cards.hand.ids)
		assert.are.equal(discard_before + 1, #player.cards.discard.ids)
	end)

	it("attack card drag to valid enemy stone commits without Use button drop", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 4)
		local hand_before = #player.cards.hand.ids
		local discard_before = #player.cards.discard.ids
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]
		local start_x = slot.x + slot.w * 0.5
		local start_y = slot.y + slot.h * 0.5
		love.mousepressed(start_x, start_y, 1)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousemoved(px, py)
		local card_ui = helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
		assert.is_true(card_ui.drag_targeting)
		assert.is_true(card_ui.drag_target_valid)
		love.mousereleased(px, py, 1)
		assert.are.equal(hand_before - 1, #player.cards.hand.ids)
		assert.are.equal(discard_before + 1, #player.cards.discard.ids)
		assert.is_true(match.board[4][4].solidity < 4)
	end)

	it("attack card drag to invalid own stone cancels play", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		local hand_before = #player.cards.hand.ids
		local discard_before = #player.cards.discard.ids
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]
		love.mousepressed(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousemoved(px, py)
		local card_ui = helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
		assert.is_true(card_ui.drag_targeting)
		assert.is_false(card_ui.drag_target_valid)
		love.mousereleased(px, py, 1)
		assert.are.equal(hand_before, #player.cards.hand.ids)
		assert.are.equal(discard_before, #player.cards.discard.ids)
		assert.are.equal(4, match.board[4][4].solidity)
	end)

	it("heal card drag validity changes from full to damaged target and commits", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_heal_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		match.board[4][5] = board.make_stone(config.STONE_BLACK, "stone_basic", 3)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]
		love.mousepressed(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)
		local full_x, full_y = layout_mod.grid_to_pixel(layout, 4, 4)
		love.mousemoved(full_x, full_y)
		local card_ui = helper.get_upvalue(helper.get_upvalue(love.mousepressed, "handle_card_press"), "card_ui")
		assert.is_true(card_ui.drag_targeting)
		assert.is_false(card_ui.drag_target_valid)
		local dmg_x, dmg_y = layout_mod.grid_to_pixel(layout, 4, 5)
		love.mousemoved(dmg_x, dmg_y)
		assert.is_true(card_ui.drag_target_valid)
		love.mousereleased(dmg_x, dmg_y, 1)
		assert.are.equal(4, match.board[4][5].solidity)
		assert.are.equal(1, #player.cards.discard.ids)
	end)

	it("dragging card to Use button plays selected drag card", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		local hand_before = #player.cards.hand.ids
		local discard_before = #player.cards.discard.ids
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]

		love.mousepressed(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)
		local use = layout_mod.card_use_button_rect(layout)
		love.mousemoved(use.x + use.w * 0.5, use.y + use.h * 0.5)
		love.mousereleased(use.x + use.w * 0.5, use.y + use.h * 0.5, 1)

		assert.are.equal(hand_before - 1, #player.cards.hand.ids)
		assert.are.equal(discard_before + 1, #player.cards.discard.ids)
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
