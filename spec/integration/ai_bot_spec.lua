require("spec.test_helper")

local config = require("config")
local game = require("game")
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
						or action.type == "PASS_TURN",
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
