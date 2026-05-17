--- Builds one MAIN-phase action queue from cheap script scoring (no MCTS / resolve_round).
--- @module ai.turn.planner

local enclosure = require("single_game.resolver.enclosure")
local placement_cheap = require("ai.heuristics.placement_cheap")
local registry = require("ai.heuristics.registry")
local scripts = require("ai.turn.scripts")
local stone_select = require("ai.heuristics.stone_select")

local M = {}

--- @param view table
--- @param script table
--- @return string|nil
local function stone_id_for_script(view, script)
	local playable = view:playable_stones()
	if #playable == 0 then
		return nil
	end
	if script.hand_index then
		return playable[stone_select.choose_index(view)]
	end
	local idx = stone_select.choose_index(view)
	return playable[idx]
end

--- @param view table
--- @param stone_id string|nil
--- @return number
local function placement_estimate(view, stone_id)
	if not stone_id then
		return 0
	end
	local walls = enclosure.extract_walls(view:board())
	return placement_cheap.best_placement_score(view, stone_id, walls)
end

--- @param view table
--- @param script table
--- @return number
local function score_script(view, script)
	local total = registry.score_stance_passive(view)
	if script.hand_index then
		total = total + registry.score_card(view, script.hand_index)
		if script.target then
			total = total
				+ registry.score_target(view, script.hand_index, script.target.row, script.target.col)
		end
	else
		total = total + 0.01
	end
	local stone_id = stone_id_for_script(view, script)
	total = total + placement_estimate(view, stone_id)
	return total
end

--- @param view table
--- @return table[] resolver-shaped actions
function M.build_plan(view)
	local game = view:raw_game()
	local max_scripts = game.ai_planner_max_scripts or 12
	local candidates = scripts.enumerate(view, max_scripts)
	local best = candidates[1]
	local best_score = score_script(view, best)
	for i = 2, #candidates do
		local script = candidates[i]
		local s = score_script(view, script)
		if s > best_score then
			best_score = s
			best = script
		end
	end
	if best_score <= 0 and candidates[1] then
		best = candidates[1]
	end
	local steps = {}
	for j = 1, #best.steps do
		steps[j] = best.steps[j]
	end
	return steps
end

return M
