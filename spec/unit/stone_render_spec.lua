local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local config = require("config")
local layout_mod = require("layout")
local match_state = require("match_state")
local atlas_params = require("objects.parameters.stone_solidity_atlas")
local render = require("render")
local resolver = require("resolver")
local sprites = require("ui.sprites")

describe("T-050 stone graphics-driven rendering path", function()
	it("draws owner ring outlines for board stones", function()
		local line_circle_calls = 0
		local original_circle = love.graphics.circle
		love.graphics.circle = function(mode, ...)
			if mode == "line" then
				line_circle_calls = line_circle_calls + 1
			end
			return original_circle(mode, ...)
		end

	local state = match_state.new_match("pvp", 300)
	state.players.black.stances.fixed = {}
	state.players.black.stances.swappable = {}
	state.players.white.stances.fixed = {}
	state.players.white.stances.swappable = {}
	assert.is_true(resolver.begin_turn(state, "black").ok)
		state.phase = "PLACE_PHASE"
		state.players.black.stones.playable_stones = { "stone_power" }
		state.players.black.stones.selected_stone_index = 1
		state.players.black.stones.selected_stone = "stone_power"
		assert.is_true(resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 1, col = 1 },
		}).ok)

		state.phase = "PLACE_PHASE"
		state.to_play = "black"
		state.players.black.stones.playable_stones = { "stone_focus" }
		state.players.black.stones.selected_stone_index = 1
		state.players.black.stones.selected_stone = "stone_focus"
		assert.is_true(resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 1, col = 2 },
		}).ok)

		local layout = layout_mod.from_window(1280, 720)
		require("ui.fonts").init()
		render.draw(state, layout, nil, nil, false, { mode = "none" }, { active = false })

		love.graphics.circle = original_circle

		assert.is_true(line_circle_calls >= 2)
	end)

	it("draws deterioration atlas quad when sheet is loaded", function()
		local quad_draws = 0
		local original_draw = love.graphics.draw
		love.graphics.draw = function(img, quad, ...)
			if quad and type(quad) == "table" and quad.getViewport then
				quad_draws = quad_draws + 1
			end
			return original_draw(img, quad, ...)
		end

		local fake_image = {
			getWidth = function()
				return 800
			end,
			getHeight = function()
				return 400
			end,
		}
		sprites.clear_cache(atlas_params.path)
		local original_get_image = sprites.get_image
		sprites.get_image = function(path)
			if path == atlas_params.path then
				return fake_image
			end
			return original_get_image(path)
		end
		love.graphics.newQuad = function(x, y, w, h, iw, ih)
			return {
				getViewport = function()
					return x, y, w, h
				end,
			}
		end
		package.loaded["ui.stone_solidity_atlas"] = nil
		package.loaded["render"] = nil
		local render_with_atlas = require("render")

		local state = match_state.new_match("pvp", 302)
		state.players.black.stances.fixed = {}
		state.players.black.stances.swappable = {}
		state.players.white.stances.fixed = {}
		state.players.white.stances.swappable = {}
		assert.is_true(resolver.begin_turn(state, "black").ok)
		state.phase = "PLACE_PHASE"
		state.players.black.stones.playable_stones = { "stone_basic" }
		state.players.black.stones.selected_stone_index = 1
		state.players.black.stones.selected_stone = "stone_basic"
		assert.is_true(resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 3, col = 3 },
		}).ok)

		local layout = layout_mod.from_window(1280, 720)
		require("ui.fonts").init()
		render_with_atlas.draw(state, layout, nil, nil, false, { mode = "none" }, { active = false })

		love.graphics.draw = original_draw
		sprites.get_image = original_get_image
		package.loaded["ui.stone_solidity_atlas"] = nil
		package.loaded["render"] = nil

		assert.is_true(quad_draws >= 1)
	end)

	it("selector row does not print stone names/descriptions by default", function()
		local printed = {}
		local original_printf = love.graphics.printf
		love.graphics.printf = function(text, ...)
			printed[#printed + 1] = tostring(text)
			return original_printf(text, ...)
		end

	local state = match_state.new_match("pvp", 301)
	state.players.black.stances.fixed = {}
	state.players.black.stances.swappable = {}
	state.players.white.stances.fixed = {}
	state.players.white.stances.swappable = {}
	assert.is_true(resolver.begin_turn(state, "black").ok)
		local layout = layout_mod.from_window(1280, 720)
		require("ui.fonts").init()
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
