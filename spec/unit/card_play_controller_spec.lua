local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local board = require("board")
local config = require("config")
local game = require("game")
local layout_mod = require("layout")
local match_state = require("match_state")
local card_play_controller = require("ui.card_play_controller")

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

local function make_ctx(match, layout)
	return {
		match = match,
		layout = layout,
		play_card = function(m, hand_index, targets)
			return game.play_card(m, hand_index, targets)
		end,
	}
end

local function setup_match()
	love.load = love.load or function() end
	local width, height = 1280, 720
	if love.graphics.getDimensions then
		width, height = love.graphics.getDimensions()
	end
	local layout = layout_mod.from_window(width, height)
	local match = game.new("pvp")
	return layout, match, make_ctx(match, layout)
end

local function hand_press(controller, ctx, card_count, target_index)
	local px, py = hand_click_point(ctx.layout, card_count, target_index)
	controller:on_press(px, py, ctx)
end

describe("card_play_controller", function()
	it("clicking cards pops selection without playing", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_point_tap", "card_small_mult" }
		player.cards.discard.ids = {}
		local count = #player.cards.hand.ids
		local p1x, p1y = hand_click_point(layout, count, 1)
		controller:on_press(p1x, p1y, ctx)
		local ui = controller:state(ctx)
		assert.are.equal("card_selected", ui.phase)
		assert.are.equal(1, ui.selected_index)
		assert.are.equal(2, #player.cards.hand.ids)
		assert.are.equal(0, #player.cards.discard.ids)
		local p2x, p2y = hand_click_point(layout, count, 2)
		controller:on_press(p2x, p2y, ctx)
		ui = controller:state(ctx)
		assert.are.equal(2, ui.selected_index)
	end)

	it("Sale Prep uses Use then Confirm with two discard targets", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult" }
		player.cards.discard.ids = {}
		local count = #player.cards.hand.ids
		hand_press(controller, ctx, count, 1)
		local ui = controller:state(ctx)
		assert.are.equal("Use", ui.action_button_label)
		assert.is_true(ui.can_use)
		local use = layout_mod.card_use_button_rect(layout)
		controller:on_press(use.x + 2, use.y + 2, ctx)
		ui = controller:state(ctx)
		assert.are.equal("discard_targets_armed", ui.phase)
		assert.are.equal("armed", ui.hand_target_phase)
		assert.is_nil(ui.selected_index)
		assert.are.equal("Confirm", ui.action_button_label)
		assert.is_false(ui.can_use)
		hand_press(controller, ctx, count, 2)
		hand_press(controller, ctx, count, 3)
		ui = controller:state(ctx)
		assert.is_true(ui.can_use)
		assert.is_true(ui.popped_target_indices[2])
		assert.is_true(ui.popped_target_indices[3])
		assert.is_nil(ui.popped_target_indices[1])
		controller:on_press(use.x + 2, use.y + 2, ctx)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.are.equal(3, #player.cards.discard.ids)
	end)

	it("Sale Prep drag to Use arms then drag to Confirm commits", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult" }
		player.cards.discard.ids = {}
		local count = #player.cards.hand.ids
		hand_press(controller, ctx, count, 1)
		local use = layout_mod.card_use_button_rect(layout)
		controller:on_move(use.x + use.w * 0.5, use.y + use.h * 0.5, ctx)
		controller:on_release(use.x + use.w * 0.5, use.y + use.h * 0.5, ctx)
		local ui = controller:state(ctx)
		assert.are.equal("discard_targets_armed", ui.phase)
		hand_press(controller, ctx, count, 2)
		hand_press(controller, ctx, count, 3)
		controller:on_press(use.x + 2, use.y + 2, ctx)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.are.equal(3, #player.cards.discard.ids)
	end)

	it("Sale Prep blocks third target and keeps status message", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult", "card_heal_1" }
		player.cards.discard.ids = {}
		local count = #player.cards.hand.ids
		hand_press(controller, ctx, count, 1)
		local use = layout_mod.card_use_button_rect(layout)
		controller:on_press(use.x + 2, use.y + 2, ctx)
		local ui = controller:state(ctx)
		assert.is_false(ui.can_use)
		hand_press(controller, ctx, count, 2)
		hand_press(controller, ctx, count, 3)
		ui = controller:state(ctx)
		assert.is_true(ui.can_use)
		hand_press(controller, ctx, count, 4)
		ui = controller:state(ctx)
		assert.are.equal(2, #ui.selected_targets)
		assert.are.equal("Target limit reached", ui.status_text)
		assert.is_true(ui.can_use)
	end)

	it("heal card stays disabled until damaged own stone target selected", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_heal_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		match.board[4][5] = board.make_stone(config.STONE_BLACK, "stone_basic", 3)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]
		controller:on_press(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, ctx)
		controller:on_release(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, ctx)
		local ui = controller:state(ctx)
		assert.is_false(ui.can_use)
		controller:on_board_stone(4, 5, ctx)
		ui = controller:state(ctx)
		assert.is_true(ui.can_use)
	end)

	it("invalid stone target shows feedback and empty selection", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_heal_1" }
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		controller:on_press(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, ctx)
		controller:on_release(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, ctx)
		controller:on_board_stone(4, 4, ctx)
		local ui = controller:state(ctx)
		assert.are.equal(0, #ui.selected_targets)
		assert.is_false(ui.can_use)
		assert.are.equal("Invalid target: missing required tags", ui.status_text)
		assert.is_not_nil(ui.invalid_target_feedback)
		assert.are.equal("stone", ui.invalid_target_feedback.object_type)
	end)

	it("attack click pops then Confirm commits with board target", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		match.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 4)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		controller:on_press(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, ctx)
		local ui = controller:state(ctx)
		assert.are.equal(1, #player.cards.hand.ids)
		controller:on_board_stone(4, 4, ctx)
		ui = controller:state(ctx)
		assert.is_true(ui.can_use)
		local use = layout_mod.card_use_button_rect(layout)
		controller:on_press(use.x + 2, use.y + 2, ctx)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.are.equal(1, #player.cards.discard.ids)
	end)

	it("stone-target drag enters target_arrow phase with focus center anchor", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		match.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 4)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[1]
		controller:on_press(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, ctx)
		local fx, fy = layout_mod.card_focus_center(layout, 1, 1)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		controller:on_move(px, py, ctx)
		local ui = controller:state(ctx)
		assert.are.equal("drag_target_arrow", ui.phase)
		assert.are.equal("target_arrow", ui.drag_mode)
		assert.is_true(ui.drag_target_valid)
		assert.are.equal(1, ui.selected_index)
		assert.are.near(fx, ui.drag_arrow_from_x, 2)
		assert.are.near(fy, ui.drag_arrow_from_y, 2)
	end)

	it("attack valid arrow drop commits play", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 4)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		controller:on_press(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, ctx)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		controller:on_move(px, py, ctx)
		controller:on_release(px, py, ctx)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.is_true(match.board[4][4].solidity < 4)
	end)

	it("attack drag to invalid own stone cancels play and keeps selection", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_attack_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		local hand_before = #player.cards.hand.ids
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		controller:on_press(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, ctx)
		local px, py = layout_mod.grid_to_pixel(layout, 4, 4)
		controller:on_move(px, py, ctx)
		local ui = controller:state(ctx)
		assert.is_false(ui.drag_target_valid)
		controller:on_release(px, py, ctx)
		assert.are.equal(hand_before, #player.cards.hand.ids)
		ui = controller:state(ctx)
		assert.are.equal(1, ui.selected_index)
		assert.are.equal(4, match.board[4][4].solidity)
	end)

	it("heal drag validity changes and valid drop commits", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_heal_1" }
		player.cards.discard.ids = {}
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		match.board[4][5] = board.make_stone(config.STONE_BLACK, "stone_basic", 3)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		controller:on_press(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, ctx)
		local full_x, full_y = layout_mod.grid_to_pixel(layout, 4, 4)
		controller:on_move(full_x, full_y, ctx)
		local ui = controller:state(ctx)
		assert.is_false(ui.drag_target_valid)
		local dmg_x, dmg_y = layout_mod.grid_to_pixel(layout, 4, 5)
		controller:on_move(dmg_x, dmg_y, ctx)
		ui = controller:state(ctx)
		assert.is_true(ui.drag_target_valid)
		controller:on_release(dmg_x, dmg_y, ctx)
		assert.are.equal(4, match.board[4][5].solidity)
		assert.are.equal(1, #player.cards.discard.ids)
	end)

	it("instant card drag to Confirm commits", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_point_tap" }
		player.cards.discard.ids = {}
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		controller:on_press(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, ctx)
		local use = layout_mod.card_use_button_rect(layout)
		controller:on_move(use.x + use.w * 0.5, use.y + use.h * 0.5, ctx)
		controller:on_release(use.x + use.w * 0.5, use.y + use.h * 0.5, ctx)
		assert.are.equal(0, #player.cards.hand.ids)
		assert.are.equal(1, #player.cards.discard.ids)
	end)

	it("reset returns idle phase", function()
		local _, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_point_tap" }
		hand_press(controller, ctx, 1, 1)
		controller:reset()
		local ui = controller:state(ctx)
		assert.are.equal("idle", ui.phase)
		assert.is_nil(ui.selected_index)
	end)

	it("update clears invalid target feedback timer", function()
		local layout, match, ctx = setup_match()
		local controller = card_play_controller.new()
		local player = match_state.player_for_color(match, match.to_play)
		player.cards.hand.ids = { "card_heal_1" }
		match.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		controller:on_press(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, ctx)
		controller:on_release(slots[1].x + slots[1].w * 0.5, slots[1].y + slots[1].h * 0.5, ctx)
		controller:on_board_stone(4, 4, ctx)
		assert.is_not_nil(controller:state(ctx).invalid_target_feedback)
		controller:update(0.6)
		assert.is_nil(controller:state(ctx).invalid_target_feedback)
	end)
end)
