--- Central bot tunables: placement, MCTS, planner, and difficulty profiles.
---
--- Precedence for ``for_game(game)``: ``game.ai_placement`` / ``game.ai_mcts`` /
--- ``game.ai_planner_enabled`` / ``game.ai_planner_max_scripts`` overrides → profile → ``M.*`` defaults.
---
--- **placement.candidate_k** (1–81): max candidates returned by movegen after filtering.
--- **placement.full_eval_top_n** (1–81): max ``evaluate_move`` calls in PLACE when the candidate list is larger.
--- **placement.prescore_enabled**: when true, cheap prescore ranks movegen and placement pools; when false, stable legal/filter order and no ``placement_cheap.top_by_cheap_score``.
--- **placement.weights**: feature weights for ``placement.evaluate_move``.
---
--- **mcts.enabled**: run shallow placement MCTS when strategy allows and ``game.ai_mcts`` exists.
--- **mcts.iterations** (0–500): root playouts per placement decision.
--- **mcts.max_rollout_depth** (1–20): alternate plies per simulation.
--- **mcts.exploration_c** (0.5–3): UCT exploration constant.
--- **mcts.fast_rollout**: use fast static eval in rollouts (no per-cell territory assignment).
--- **mcts.max_decision_ms** (0–500): wall-clock budget; 0 = no time cap.
---
--- **planner.enabled**: MAIN uses turn script planner vs stone-only.
--- **planner.max_scripts** (1–32): cap enumerated MAIN scripts per plan build.
---
--- **scoring.decision_mode**:
--- - ``"absolute"``: maximize own-side heuristic only (placement deltas, eval for self).
--- - ``"margin"``: maximize ``my_score - opp_score`` (same heuristics from each side).
--- @module ai.config

local M = {}

M.placement = {
	candidate_k = 81,
	full_eval_top_n = 81,
	prescore_enabled = false,
	weights = {
		delta_territory_me = 4.0,
		delta_captures = 12.0,
		delta_enclosure_inside = 2.5,
		closes_region = 3.0,
		frontier = 2.0,
		contested_pressure = 1.5,
		weak_boundary_penalty = -1.0,
		self_fill_penalty = -6.0,
	},
}

M.mcts = {
	enabled = false,
	iterations = 0,
	max_rollout_depth = 3,
	exploration_c = 1.4,
	fast_rollout = true,
	max_decision_ms = 80,
}

M.planner = {
	enabled = true,
	max_scripts = 12,
}

M.scoring = {
	decision_mode = "absolute",
}

M.profiles = {
	easy = {
		placement = {
			candidate_k = 24,
			full_eval_top_n = 6,
			prescore_enabled = true,
		},
		mcts = {
			enabled = false,
			iterations = 0,
			max_rollout_depth = 2,
			max_decision_ms = 0,
		},
		planner = {
			enabled = true,
			max_scripts = 10,
		},
	},
	normal = {
		placement = {
			candidate_k = 81,
			full_eval_top_n = 81,
			prescore_enabled = false,
		},
		mcts = {
			enabled = true,
			iterations = 1800,
			max_rollout_depth = 5,
			max_decision_ms = 10000,
		},
		planner = {
			enabled = true,
			max_scripts = 12,
		},
		scoring = {
			decision_mode = "margin",
		},
	},
	hard = {
		placement = {
			candidate_k = 30,
			full_eval_top_n = 8,
			prescore_enabled = true,
		},
		mcts = {
			enabled = true,
			iterations = 20,
			max_rollout_depth = 3,
			max_decision_ms = 100,
		},
		planner = {
			enabled = true,
			max_scripts = 12,
		},
	},
}

--- @param dst table
--- @param src table|nil
--- @return table
local function merge_section(dst, src)
	if not src then
		return dst
	end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" and k ~= "weights" then
			merge_section(dst[k], v)
		else
			dst[k] = v
		end
	end
	return dst
end

--- @param t table
--- @return table
local function shallow_copy_table(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

--- @param profile table
--- @return table
local function resolved_from_profile(profile)
	return {
		placement = merge_section(shallow_copy_table(M.placement), profile.placement),
		mcts = merge_section(shallow_copy_table(M.mcts), profile.mcts),
		planner = merge_section(shallow_copy_table(M.planner), profile.planner),
		scoring = merge_section(shallow_copy_table(M.scoring), profile.scoring),
	}
end

--- @param game table
--- @param profile_name string
--- @return nil
function M.apply_profile(game, profile_name)
	local profile = M.profiles[profile_name] or M.profiles.normal
	game.ai_difficulty = profile_name
	game.ai_planner_enabled = profile.planner and profile.planner.enabled or M.planner.enabled
	game.ai_planner_max_scripts = profile.planner and profile.planner.max_scripts or M.planner.max_scripts
	game.ai_mcts = shallow_copy_table(M.mcts)
	merge_section(game.ai_mcts, profile.mcts)
	game.ai_placement = shallow_copy_table(M.placement)
	merge_section(game.ai_placement, profile.placement)
	game.ai_scoring = shallow_copy_table(M.scoring)
	merge_section(game.ai_scoring, profile.scoring)
end

--- @param game table|nil
--- @return table
function M.for_game(game)
	local profile_name = (game and game.ai_difficulty) or "normal"
	local profile = M.profiles[profile_name] or M.profiles.normal
	local resolved = resolved_from_profile(profile)
	if game then
		if game.ai_placement then
			merge_section(resolved.placement, game.ai_placement)
		end
		if game.ai_mcts then
			merge_section(resolved.mcts, game.ai_mcts)
		end
		if game.ai_planner_enabled ~= nil then
			resolved.planner.enabled = game.ai_planner_enabled
		end
		if game.ai_planner_max_scripts then
			resolved.planner.max_scripts = game.ai_planner_max_scripts
		end
		if game.ai_scoring then
			merge_section(resolved.scoring, game.ai_scoring)
		end
	end
	return resolved
end

--- @param game table|nil
--- @param strategy string|nil
--- @return boolean
function M.mcts_should_run(game, strategy)
	local mcts = M.for_game(game).mcts
	if strategy == "heuristic" then
		if game and game.ai_mcts and game.ai_mcts.enabled == false then
			return false
		end
		if not game or not game.ai_mcts then
			return false
		end
		return mcts.enabled == true and (mcts.iterations or 0) > 0
	end
	if strategy == "mcts" then
		return mcts.enabled ~= false and (mcts.iterations or 0) > 0
	end
	return mcts.enabled == true and (mcts.iterations or 0) > 0
end

return M
