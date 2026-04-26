local content = require("content")
local match_state = require("match_state")
local resolver = require("resolver")
local rules = require("rules")
local config = require("config")
local helper = require("spec.test_helper")

describe("T-050 stone metadata and behavior hooks", function()
	it("defines required stone metadata fields", function()
		for stone_id, stone in pairs(content.stones) do
			assert.are.equal(stone_id, stone.id)
			assert.is_true(type(stone.name) == "string" and #stone.name > 0)
			assert.is_true(type(stone.description) == "string" and #stone.description > 0)
			assert.is_true(type(stone.depiction) == "string" and #stone.depiction > 0)
			assert.is_true(type(stone.graphic) == "table")
			assert.is_true(type(stone.graphic.draw_key) == "string" and #stone.graphic.draw_key > 0)
			assert.is_true(type(stone.behavior) == "function")
		end
	end)

	it("behavior pointer returns valid effect payload for each stone", function()
		local state = match_state.new_match("pvp", 201)
		for _, stone in pairs(content.stones) do
			local effects = stone.behavior(state, "black")
			assert.is_true(type(effects) == "table" and #effects > 0)
			for i = 1, #effects do
				local effect = effects[i]
				assert.is_true(type(effect) == "table")
				assert.is_true(effect.type == "ADD_POINTS" or effect.type == "ADD_MULT")
				assert.is_true(type(effect.value) == "number")
			end
		end
	end)

	it("resolver consumes stone behavior effect payload on placement", function()
		local state = match_state.new_match("pvp", 202)
		state.players.black.poses.fixed = {}
		state.players.black.poses.swappable = {}
		state.players.white.poses.fixed = {}
		state.players.white.poses.swappable = {}
		assert.is_true(resolver.begin_turn(state, "black").ok)
		assert.is_true(resolver.finish_main_phase(state, "black").ok)

		local black = state.players.black
		black.stones.playable_stones = { "stone_focus" }
		black.stones.selected_stone = "stone_focus"
		black.score.mult_bonus = 0

		local legal_moves = rules.all_legal_moves(state.board, config.STONE_BLACK, state.ko_ban, "stone_focus")
		local move = legal_moves[1]
		local result = resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = move[1], col = move[2] },
		})

		assert.is_true(result.ok)
		assert.are.equal(1, black.score.mult_bonus)
		assert.are.equal("Focus Stone placement: +1 mult", state.messages.recent[#state.messages.recent])
	end)

	it("rejects invalid behavior payload without board mutation", function()
		local state = match_state.new_match("pvp", 203)
		state.players.black.poses.fixed = {}
		state.players.black.poses.swappable = {}
		state.players.white.poses.fixed = {}
		state.players.white.poses.swappable = {}
		assert.is_true(resolver.begin_turn(state, "black").ok)
		assert.is_true(resolver.finish_main_phase(state, "black").ok)

		local black = state.players.black
		local stone = content.stones.stone_basic
		local original_behavior = stone.behavior
		stone.behavior = function()
			return { { type = "BAD", value = "x" } }
		end

		black.stones.playable_stones = { "stone_basic" }
		black.stones.selected_stone = "stone_basic"
		local board_before = helper.copy_ids({})
		for r = 1, #state.board do
			board_before[r] = {}
			for c = 1, #state.board[r] do
				board_before[r][c] = state.board[r][c]
			end
		end
		local legal_moves = rules.all_legal_moves(state.board, config.STONE_BLACK, state.ko_ban, "stone_basic")
		local move = legal_moves[1]
		local result = resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = move[1], col = move[2] },
		})

		stone.behavior = original_behavior
		assert.is_false(result.ok)
		assert.are.equal("Stone behavior produced invalid effect", result.error)
		assert.are.equal("PLACE_PHASE", state.phase)
		assert.is_true(state.board[move[1]][move[2]] == board_before[move[1]][move[2]])
	end)
end)
