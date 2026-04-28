local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local config = require("config")
local board = require("board")
local layout_mod = require("layout")
local match_state = require("match_state")
local render = require("render")
local resolver = require("resolver")
local rules = require("rules")

local function new_started_state(seed)
	local state = match_state.new_match("pvp", seed or 1)
	state.players.black.poses.fixed = {}
	state.players.black.poses.swappable = {}
	state.players.white.poses.fixed = {}
	state.players.white.poses.swappable = {}
	assert.is_true(resolver.begin_turn(state, "black").ok)
	assert.is_true(resolver.finish_main_phase(state, "black").ok)
	return state
end

describe("Territory runtime integration", function()
	it("recomputes state.territory immediately after legal placement", function()
		local state = new_started_state(401)
		local before = state.territory
		state.players.black.stones.playable_stones = { "stone_basic" }
		state.players.black.stones.selected_stone = "stone_basic"
		local legal = rules.all_legal_moves(state.board, config.STONE_BLACK, state.ko_ban, "stone_basic")[1]
		assert.is_true(resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = legal[1], col = legal[2] },
		}).ok)
		assert.is_true(type(state.territory) == "table")
		assert.is_true(before ~= state.territory)
	end)

	it("emits score delta events in points-then-mult order", function()
		local state = new_started_state(402)
		state.players.black.stones.playable_stones = { "stone_focus" }
		state.players.black.stones.selected_stone = "stone_focus"
		local legal = rules.all_legal_moves(state.board, config.STONE_BLACK, state.ko_ban, "stone_focus")[1]
		assert.is_true(resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = legal[1], col = legal[2] },
		}).ok)
		local events = state.messages.score_events
		assert.is_true(#events >= 1)
		local first_points, first_mult = nil, nil
		for i = 1, #events do
			if events[i].kind == "points" and not first_points then
				first_points = i
			end
			if events[i].kind == "mult" and not first_mult then
				first_mult = i
			end
		end
		if first_points and first_mult then
			assert.is_true(first_points < first_mult)
		end
	end)

	it("renders tinted territory cells that match state.territory ownership", function()
		local state = new_started_state(403)
		local black = state.players.black
		black.stones.playable_stones = { "stone_basic" }
		black.stones.selected_stone = "stone_basic"
		local legal = rules.all_legal_moves(state.board, config.STONE_BLACK, state.ko_ban, "stone_basic")[1]
		assert.is_true(resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = legal[1], col = legal[2] },
		}).ok)

		local black_cells = 0
		local white_cells = 0
		for r = 1, config.BOARD_SIZE do
			for c = 1, config.BOARD_SIZE do
				if board.is_empty(state.board[r][c]) and state.territory[r][c] == config.STONE_BLACK then
					black_cells = black_cells + 1
				elseif board.is_empty(state.board[r][c]) and state.territory[r][c] == config.STONE_WHITE then
					white_cells = white_cells + 1
				end
			end
		end

		local current_color = { 1, 1, 1, 1 }
		local black_tint_rects = 0
		local white_tint_rects = 0
		local original_set_color = love.graphics.setColor
		local original_rectangle = love.graphics.rectangle
		love.graphics.setColor = function(r, g, b, a)
			current_color = { r, g, b, a }
			return original_set_color(r, g, b, a)
		end
		love.graphics.rectangle = function(mode, ...)
			if mode == "fill" then
				if current_color[1] == 0.18 and current_color[2] == 0.28 and current_color[3] == 0.46 then
					black_tint_rects = black_tint_rects + 1
				elseif current_color[1] == 0.92 and current_color[2] == 0.92 and current_color[3] == 0.94 then
					white_tint_rects = white_tint_rects + 1
				end
			end
			return original_rectangle(mode, ...)
		end

		local layout = layout_mod.from_window(1280, 720)
		render.draw(state, layout, nil, nil, false, { mode = "none" }, { active = false })

		love.graphics.setColor = original_set_color
		love.graphics.rectangle = original_rectangle

		assert.are.equal(black_cells, black_tint_rects)
		assert.are.equal(white_cells, white_tint_rects)
	end)

	it("pauses AI tick while score animation is active", function()
		helper.reset_module("main")
		local ai_ticks = 0
		helper.set_upvalue(love.update, "screen", "play")
		helper.set_upvalue(love.update, "match", { messages = { score_events = {} } })
		helper.set_upvalue(love.update, "game", {
			tick_ai = function()
				ai_ticks = ai_ticks + 1
			end,
		})
		helper.set_upvalue(love.update, "render", {
			update = function() end,
			is_score_animating = function()
				return true
			end,
		})
		love.update(0.016)
		assert.are.equal(0, ai_ticks)

		helper.set_upvalue(love.update, "render", {
			update = function() end,
			is_score_animating = function()
				return false
			end,
		})
		love.update(0.016)
		assert.are.equal(1, ai_ticks)
	end)
end)
