--- Bot strategy: full MAIN plan (optional cards) + PLACE placement.
--- @module ai.strategies.heuristic

local ai_config = require("ai.config")
local dual_suggest = require("ai.candidates.dual_suggest")
local enclosure = require("single_game.resolver.enclosure")
local features = require("ai.board_analysis.features")
local goals = require("ai.heuristics.goals")
local movegen = require("ai.movegen.placement_candidates")
local placement = require("ai.heuristics.placement")
local plan = require("ai.turn.plan")
local planner = require("ai.turn.planner")
local stone_select = require("ai.heuristics.stone_select")
local territory_analysis = require("ai.board_analysis.territory")

local M = {}

--- @param view table
--- @return boolean
local function stone_selection_complete(view)
	local playable = view:playable_stones()
	if #playable == 0 then
		return true
	end
	local idx = stone_select.choose_index(view)
	local stone_id = playable[idx]
	return view:selected_stone_index() == idx and view:selected_stone_id() == stone_id
end

--- @param view table
--- @return table|nil action
--- @return string|nil signal
local function main_phase_stone_only(view)
	local playable = view:playable_stones()
	if #playable == 0 then
		return nil, "finish_main"
	end
	local idx = stone_select.choose_index(view)
	local stone_id = playable[idx]
	if view:selected_stone_index() == idx and view:selected_stone_id() == stone_id then
		return nil, "finish_main"
	end
	return {
		actor = view:actor(),
		type = "SELECT_STONE",
		payload = { stone_id = stone_id, stone_index = idx },
	}
end

--- @param view table
--- @return table|nil action
--- @return string|nil signal
local function main_phase_planner(view)
	local game = view:raw_game()
	if not plan.has_steps(game) then
		plan.set(game, planner.build_plan(view))
	end
	local action = plan.pop_valid(view)
	if action then
		return action
	end
	if stone_selection_complete(view) then
		return nil, "finish_main"
	end
	plan.set(game, planner.build_plan(view))
	action = plan.pop_valid(view)
	if action then
		return action
	end
	return nil, "finish_main"
end

--- @param view table
--- @return table|nil
local function placement_suggestion(view)
	return ai_config.for_game(view:raw_game()).placement.suggestion
end

--- @param view table
--- @return table|nil action
--- @return string|nil signal
local function main_phase(view)
	local suggestion = placement_suggestion(view)
	if suggestion and suggestion.enabled and suggestion.stone_only_main then
		return main_phase_stone_only(view)
	end
	if view:planner_enabled() then
		return main_phase_planner(view)
	end
	return main_phase_stone_only(view)
end

--- @param view table
--- @param stone_id string
--- @return integer|nil
local function stone_index_for_id(view, stone_id)
	local playable = view:playable_stones()
	for i = 1, #playable do
		if playable[i] == stone_id then
			return i
		end
	end
	return nil
end

--- @param view table
--- @return table|nil action
--- @return string|nil signal
local function place_phase_dual(view)
	local best, _merged = dual_suggest.choose_placement(view)
	if not best then
		return {
			actor = view:actor(),
			type = "PASS_TURN",
			payload = {},
		}
	end
	local stone_index = stone_index_for_id(view, best.stone_id)
	if not stone_index then
		return {
			actor = view:actor(),
			type = "PASS_TURN",
			payload = {},
		}
	end
	local selected_id = view:selected_stone_id()
	local selected_index = view:selected_stone_index()
	if selected_id ~= best.stone_id or selected_index ~= stone_index then
		return {
			actor = view:actor(),
			type = "SELECT_STONE",
			payload = { stone_id = best.stone_id, stone_index = stone_index },
		}
	end
	return {
		actor = view:actor(),
		type = "PLACE_STONE",
		payload = { row = best.row, col = best.col },
	}
end

--- @param view table
--- @return table|nil action
--- @return string|nil signal
local function place_phase(view)
	local stone_id = view:selected_stone_id()
	if not stone_id then
		return {
			actor = view:actor(),
			type = "PASS_TURN",
			payload = {},
		}
	end
	local b = view:board()
	local mode = view:territory_mode()
	local owner_key = view:owner_key()
	local territory_before = territory_analysis.analyze(b, mode, owner_key)
	local walls = enclosure.extract_walls(b)
	local candidates = movegen.top_candidates(view, stone_id, nil, territory_before, walls)
	if #candidates == 0 then
		return {
			actor = view:actor(),
			type = "PASS_TURN",
			payload = {},
		}
	end
	local base = features.build(b, view:ko_ban(), owner_key, mode, view:stone_color(), territory_before, walls)
	goals.refresh(view, base, territory_before)
	local best = placement.best_candidate(view, candidates, stone_id, base, territory_before)
	if not best then
		local pick = candidates[view:rng_next_int(#candidates)]
		return {
			actor = view:actor(),
			type = "PLACE_STONE",
			payload = { row = pick.row, col = pick.col },
		}
	end
	return {
		actor = view:actor(),
		type = "PLACE_STONE",
		payload = { row = best.row, col = best.col },
	}
end

--- @param view table
--- @return table|nil action
--- @return string|nil signal
function M.choose_action(view)
	if view:to_play() ~= view:actor() then
		return nil
	end
	if view:phase() == "MAIN_PHASE" then
		return main_phase(view)
	end
	if view:phase() == "PLACE_PHASE" then
		local suggestion = placement_suggestion(view)
		if suggestion and suggestion.enabled then
			return place_phase_dual(view)
		end
		return place_phase(view)
	end
	return nil
end

return M
