local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local config = require("config")
local layout_mod = require("layout")
local match_state = require("match_state")
local render = require("render")
local resolver = require("resolver")

describe("T-050 stone graphics-driven rendering path", function()
	it("uses graphic draw_key-specific marks for board stones", function()
		local polygon_calls = 0
		local line_circle_calls = 0
		local original_polygon = love.graphics.polygon
		local original_circle = love.graphics.circle
		love.graphics.polygon = function(...)
			polygon_calls = polygon_calls + 1
			return original_polygon(...)
		end
		love.graphics.circle = function(mode, ...)
			if mode == "line" then
				line_circle_calls = line_circle_calls + 1
			end
			return original_circle(mode, ...)
		end

		local state = match_state.new_match("pvp", 300)
		state.players.black.poses.fixed = {}
		state.players.black.poses.swappable = {}
		state.players.white.poses.fixed = {}
		state.players.white.poses.swappable = {}
		assert.is_true(resolver.begin_turn(state, "black").ok)
		state.phase = "PLACE_PHASE"
		state.players.black.stones.playable_stones = { "stone_power" }
		state.players.black.stones.selected_stone = "stone_power"
		assert.is_true(resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 1, col = 1 },
		}).ok)

		state.phase = "PLACE_PHASE"
		state.to_play = "black"
		state.players.black.stones.playable_stones = { "stone_focus" }
		state.players.black.stones.selected_stone = "stone_focus"
		assert.is_true(resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 1, col = 2 },
		}).ok)

		local layout = layout_mod.from_window(1280, 720)
		render.draw(state, layout, nil, nil, false, { mode = "none" }, { active = false })

		love.graphics.polygon = original_polygon
		love.graphics.circle = original_circle

		assert.is_true(polygon_calls > 0)
		assert.is_true(line_circle_calls > 0)
	end)

	it("selector row does not print stone names/descriptions by default", function()
		local printed = {}
		local original_printf = love.graphics.printf
		love.graphics.printf = function(text, ...)
			printed[#printed + 1] = tostring(text)
			return original_printf(text, ...)
		end

		local state = match_state.new_match("pvp", 301)
		state.players.black.poses.fixed = {}
		state.players.black.poses.swappable = {}
		state.players.white.poses.fixed = {}
		state.players.white.poses.swappable = {}
		assert.is_true(resolver.begin_turn(state, "black").ok)
		local layout = layout_mod.from_window(1280, 720)
		render.draw(state, layout, nil, nil, false, { mode = "none" }, { active = false })
		love.graphics.printf = original_printf

		for _, text in ipairs(printed) do
			assert.is_nil(string.find(text, "Basic Stone", 1, true))
			assert.is_nil(string.find(text, "Power Stone", 1, true))
			assert.is_nil(string.find(text, "Focus Stone", 1, true))
			assert.is_nil(string.find(text, "Steady placement stone", 1, true))
			assert.is_nil(string.find(text, "Heavy placement stone", 1, true))
			assert.is_nil(string.find(text, "Precision stone", 1, true))
		end
	end)
end)
