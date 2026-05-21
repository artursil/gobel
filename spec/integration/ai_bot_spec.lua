require("spec.test_helper")

local board = require("board")
local config = require("config")
local dual_suggest = require("ai.candidates.dual_suggest")
local game = require("game")
local match_view = require("ai.adapters.match_view")
local resolver = require("resolver")
local ai_controller = require("ai.controller")
local test_helper = require("spec.test_helper")

local function bot_actor()
	return config.AI_COLOR == config.STONE_WHITE and "white" or "black"
end

local function new_pvc_bot_game()
	local g = game.new("pvc")
	g.ai_delay = 0
	if g.ai_mcts then
		g.ai_mcts.iterations = 12
		g.ai_mcts.max_rollout_depth = 3
	end
	return g
end

describe("AI bot integration", function()
	it("PVC normal uses fast heuristic without MCTS", function()
		local g = new_pvc_bot_game()
		assert.is_not_nil(g.ai_mcts)
		assert.is_false(g.ai_mcts.enabled)
		if g.to_play == "black" then
			assert.is_true(resolver.finish_main_phase(g, "black").ok)
			assert.is_true(resolver.submit_action(g, {
				actor = "black",
				type = "PLACE_STONE",
				payload = { row = 4, col = 4 },
			}).ok)
			test_helper.finish_ui_animations_for_turn(g)
		end
		assert.are.equal(bot_actor(), g.to_play)
		local steps = 0
		while g.to_play == bot_actor() and not g.ended and steps < 80 do
			local action, signal = ai_controller.decide(g)
			if signal == "finish_main" then
				assert.is_true(resolver.finish_main_phase(g, g.to_play).ok)
			elseif action then
				assert.is_true(resolver.submit_action(g, action).ok)
			else
				break
			end
			steps = steps + 1
		end
		assert.is_true(steps > 0)
	end)

	it("completes bot MAIN and PLACE without resolver errors", function()
		local g = new_pvc_bot_game()
		if g.to_play == "black" then
			assert.is_true(resolver.finish_main_phase(g, "black").ok)
			local placed = resolver.submit_action(g, {
				actor = "black",
				type = "PLACE_STONE",
				payload = { row = 5, col = 5 },
			})
			assert.is_true(placed.ok, placed.error)
			test_helper.finish_ui_animations_for_turn(g)
		end
		assert.are.equal(bot_actor(), g.to_play)
		local steps = 0
		while g.to_play == bot_actor() and not g.ended and steps < 80 do
			local action, signal = ai_controller.decide(g)
			if signal == "finish_main" then
				local result = resolver.finish_main_phase(g, g.to_play)
				assert.is_true(result.ok, result.error)
			elseif action then
				assert.are.equal(bot_actor(), action.actor)
				assert.is_true(
					action.type == "SELECT_STONE"
						or action.type == "PLACE_STONE"
						or action.type == "PASS_TURN"
						or action.type == "PLAY_CARD"
						or action.type == "SELECT_BOARD_TARGET",
					action.type
				)
				local result = resolver.submit_action(g, action)
				assert.is_true(result.ok, result.error)
			else
				break
			end
			steps = steps + 1
		end
		assert.is_true(steps > 0)
		assert.is_true(g.phase == "PLACE_PHASE" or g.to_play == "black" or g.ended)
	end)

	it("planner on: can emit PLAY_CARD and complete MAIN", function()
		local g = new_pvc_bot_game()
		g.ai_planner_enabled = true
		g.phase = "MAIN_PHASE"
		g.to_play = bot_actor()
		g.players[bot_actor()].cards.hand.ids = { "card_point_tap" }
		g.players[bot_actor()].resources.energy_current = 3
		local saw_play = false
		for _ = 1, 20 do
			if g.phase ~= "MAIN_PHASE" or g.to_play ~= bot_actor() then
				break
			end
			local action, signal = ai_controller.decide(g)
			if signal == "finish_main" then
				assert.is_true(resolver.finish_main_phase(g, g.to_play).ok)
			elseif action then
				if action.type == "PLAY_CARD" then
					saw_play = true
				end
				assert.is_true(resolver.submit_action(g, action).ok, g.status)
			else
				break
			end
		end
		assert.is_true(saw_play)
		assert.is_true(g.phase == "PLACE_PHASE" or g.ended)
	end)

	it("planner off: stone-only MAIN regression", function()
		local g = new_pvc_bot_game()
		g.ai_planner_enabled = false
		g.phase = "MAIN_PHASE"
		g.to_play = bot_actor()
		local bot = bot_actor()
		g.players[bot].cards.hand.ids = { "card_point_tap" }
		g.players[bot].resources.energy_current = 3
		g.players[bot].stones.selected_stone = nil
		g.players[bot].stones.selected_stone_index = nil
		local action = ai_controller.decide(g)
		assert.is_not_nil(action)
		assert.are.equal("SELECT_STONE", action.type)
	end)

	it("dual suggestion selects stone before place when needed", function()
		local g = new_pvc_bot_game()
		g.ai_placement = g.ai_placement or {}
		g.ai_placement.suggestion = {
			enabled = true,
			stone_only_main = true,
			n_heuristic = 8,
			n_score = 8,
			max_stones = 0,
			max_legal_per_stone = 0,
		}
		g.ai_planner_enabled = true
		g.phase = "MAIN_PHASE"
		g.to_play = bot_actor()
		g.players[bot_actor()].cards.hand.ids = { "card_point_tap" }
		g.players[bot_actor()].resources.energy_current = 3
		local main_steps = 0
		while g.phase == "MAIN_PHASE" and g.to_play == bot_actor() and main_steps < 20 do
			local action, signal = ai_controller.decide(g)
			if signal == "finish_main" then
				assert.is_true(resolver.finish_main_phase(g, g.to_play).ok)
			elseif action then
				assert.are_not.equal("PLAY_CARD", action.type)
				assert.is_true(resolver.submit_action(g, action).ok, g.status)
			else
				break
			end
			main_steps = main_steps + 1
		end
		assert.are.equal("PLACE_PHASE", g.phase)
		assert.are.equal(bot_actor(), g.to_play)

		local actor = bot_actor()
		local player = g.players[actor]
		player.stones.playable_stones = { "stone_basic", "stone_power" }
		g.board = board.new()
		local view = match_view.for_bot(g)
		local best, _merged = dual_suggest.choose_placement(view)
		assert.is_not_nil(best)
		local wrong_index = 1
		if player.stones.playable_stones[1] == best.stone_id then
			wrong_index = 2
		end
		player.stones.selected_stone = player.stones.playable_stones[wrong_index]
		player.stones.selected_stone_index = wrong_index

		local select_action = ai_controller.decide(g)
		assert.is_not_nil(select_action)
		assert.are.equal("SELECT_STONE", select_action.type)
		assert.are.equal(best.stone_id, select_action.payload.stone_id)
		assert.is_true(resolver.submit_action(g, select_action).ok, g.status)

		local place_action = ai_controller.decide(g)
		assert.is_not_nil(place_action)
		assert.are.equal("PLACE_STONE", place_action.type)
		assert.are.equal(best.row, place_action.payload.row)
		assert.are.equal(best.col, place_action.payload.col)
		assert.is_true(resolver.submit_action(g, place_action).ok, g.status)
	end)

	it("tick_ai advances bot turn when delay elapsed", function()
		local g = new_pvc_bot_game()
		if g.to_play == "black" then
			assert.is_true(resolver.finish_main_phase(g, "black").ok)
			assert.is_true(resolver.submit_action(g, {
				actor = "black",
				type = "PLACE_STONE",
				payload = { row = 3, col = 3 },
			}).ok)
			test_helper.finish_ui_animations_for_turn(g)
		end
		assert.are.equal(bot_actor(), g.to_play)
		for _ = 1, 12 do
			if g.to_play ~= bot_actor() or g.ended then
				break
			end
			g.ai_delay = 0
			game.tick_ai(g, 0)
		end
		assert.is_true(g.to_play == "black" or g.ended)
	end)
end)
