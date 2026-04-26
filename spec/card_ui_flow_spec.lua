local helper = require("spec.test_helper")

helper.install_love_test_stubs()
helper.reset_module("main")

local game = require("game")
local layout_mod = require("layout")
local match_state = require("match_state")

local function setup_play_state()
	love.load()
	local width, height = love.graphics.getDimensions()
	local layout = layout_mod.from_window(width, height)
	local match = game.new("pvp")
	helper.set_upvalue(love.mousepressed, "screen", "play")
	helper.set_upvalue(love.mousepressed, "layout", layout)
	helper.set_upvalue(love.mousepressed, "match", match)
	helper.set_upvalue(love.mousepressed, "popup_state", { mode = "none", stones = {} })
	helper.set_upvalue(love.mousepressed, "stone_drag", { active = false })
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
	helper.set_upvalue(love.mousereleased, "stone_drag", { active = false })
	helper.set_upvalue(love.mousereleased, "card_ui", helper.get_upvalue(love.mousepressed, "card_ui"))
	return layout, match
end

describe("Card UI flow", function()
	it("selects a card on click and plays through Use button", function()
		local layout, match = setup_play_state()
		local player = match_state.player_for_color(match, match.to_play)
		local hand_before = #player.cards.hand.ids
		local discard_before = #player.cards.discard.ids

		local slots = layout_mod.hand_fan_slots(layout, #player.cards.hand.ids)
		local slot = slots[#slots]
		love.mousepressed(slot.x + slot.w * 0.5, slot.y + slot.h * 0.5, 1)

		local card_ui = helper.get_upvalue(love.mousepressed, "card_ui")
		assert.are.equal(#slots, card_ui.selected_index)

		local use = layout_mod.card_use_button_rect(layout)
		love.mousepressed(use.x + 2, use.y + 2, 1)
		assert.are.equal(hand_before - 1, #player.cards.hand.ids)
		assert.are.equal(discard_before + 1, #player.cards.discard.ids)
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
