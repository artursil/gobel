--- Central bot tunables: placement, MCTS, planner, and difficulty profiles.
---
--- Precedence for ``for_game(game)``: ``game.ai_placement`` / ``game.ai_mcts`` /
--- ``game.ai_planner_enabled`` / ``game.ai_planner_max_scripts`` overrides → profile → ``M.*`` defaults.
---
--- **placement.candidate_k** (1–81): max candidates returned by movegen after filtering.
--- **placement.full_eval_top_n** (1–81): max ``evaluate_selection`` calls in PLACE when the candidate list is larger.
--- **placement.prescore_enabled**: when true, cheap prescore ranks movegen and placement pools; when false, stable legal/filter order and no ``placement_cheap.top_by_cheap_score``.
--- **placement.suggestion**: dual ranker pool for PLACE (``enabled``, ``stone_only_main``, ``n_heuristic``, ``n_score``, ``max_stones``, ``max_legal_per_stone``; 0 caps = unlimited).
---
--- **placement.heuristics_pre_selection**: term ids for stage-1 fast prescore / dual-suggest heuristic ranker.
--- **placement.heuristics_selection**: term ids for stage-2 full selection eval + MCTS root-child signal.
--- **placement.weights_pre_selection** / **placement.weights_selection**: both tiers default to legacy placement weights; pre adds ``territory_owner_change`` (~10) for movegen prescore.
---
--- Legacy ``game.ai_placement.weights`` merges into **both** weight tiers. Legacy ``placement.heuristics`` (``{ id, enabled }``) still filters selection terms when set on the game.
---
--- **mcts.enabled**: run shallow placement MCTS when strategy allows and ``game.ai_mcts`` exists.
--- **mcts.iterations** (0–500): root playouts per placement decision.
--- **mcts.placement_tree_depth** (1+): search tree expansion plies (1 = root arms only; >1 currently falls back to 1).
--- **mcts.max_rollout_depth** (1–20): rollout plies after the expanded node.
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

local PLACEMENT_TERM_IDS = {
	"delta_territory_me",
	"delta_captures",
	"delta_enclosure_inside",
	"closes_region",
	"frontier",
	"contested_pressure",
	"weak_boundary_penalty",
	"self_fill_penalty",
	"goals_bonus",
}

--- @param list table[]
--- @return table[]
local function copy_heuristics_list(list)
	local out = {}
	for i = 1, #list do
		out[i] = { id = list[i].id, enabled = list[i].enabled }
	end
	return out
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

local LEGACY_PLACEMENT_WEIGHTS = {
	delta_territory_me = 4.0,
	delta_captures = 12.0,
	delta_enclosure_inside = 2.5,
	closes_region = 3.0,
	frontier = 2.0,
	contested_pressure = 1.5,
	weak_boundary_penalty = -1.0,
	self_fill_penalty = -6.0,
}

--- @return table
local function legacy_weights_copy()
	return shallow_copy_table(LEGACY_PLACEMENT_WEIGHTS)
end

--- @return table[]
local function default_legacy_heuristics_list()
	local list = {}
	for i = 1, #PLACEMENT_TERM_IDS do
		list[i] = { id = PLACEMENT_TERM_IDS[i], enabled = true }
	end
	return list
end

M.placement = {
	candidate_k = 81,
	full_eval_top_n = 81,
	prescore_enabled = false,
	suggestion = {
		enabled = false,
		stone_only_main = true,
		n_heuristic = 8,
		n_score = 8,
		max_stones = 0,
		max_legal_per_stone = 0,
	},
	heuristics_pre_selection = { "delta_captures", "frontier", "territory_owner_change" },
	heuristics_selection = {
		"delta_territory_me",
		"delta_captures",
		"delta_enclosure_inside",
		"closes_region",
		"frontier",
		"contested_pressure",
		"weak_boundary_penalty",
		"self_fill_penalty",
		"goals_bonus",
	},
	weights_pre_selection = (function()
		local w = legacy_weights_copy()
		w.territory_owner_change = 10
		return w
	end)(),
	weights_selection = legacy_weights_copy(),
}

M.mcts = {
	enabled = false,
	iterations = 0,
	placement_tree_depth = 1,
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
			enabled = false,
			iterations = 0,
			max_rollout_depth = 5,
			max_decision_ms = 0,
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
		if k == "weights" then
			merge_section(dst.weights_pre_selection, v)
			merge_section(dst.weights_selection, v)
		elseif k == "weights_selection" or k == "weights_pre_selection" then
			merge_section(dst[k], v)
		elseif k == "heuristics" then
			dst.heuristics = copy_heuristics_list(v)
		elseif type(v) == "table" and type(dst[k]) == "table" and k ~= "suggestion" then
			if k == "heuristics_pre_selection" or k == "heuristics_selection" then
				dst[k] = v
			else
				merge_section(dst[k], v)
			end
		else
			dst[k] = v
		end
	end
	return dst
end

--- @param base table[]
--- @param override table[]|nil
--- @return table[]
local function merge_heuristics_list(base, override)
	if not override then
		return copy_heuristics_list(base)
	end
	local enabled_map = {}
	for i = 1, #override do
		enabled_map[override[i].id] = override[i].enabled
	end
	local out = {}
	for i = 1, #base do
		local entry = base[i]
		local enabled = entry.enabled
		if enabled_map[entry.id] ~= nil then
			enabled = enabled_map[entry.id]
		end
		out[#out + 1] = { id = entry.id, enabled = enabled }
	end
	return out
end

--- @param src table
--- @return table
local function copy_suggestion(src)
	return {
		enabled = src.enabled,
		stone_only_main = src.stone_only_main,
		n_heuristic = src.n_heuristic,
		n_score = src.n_score,
		max_stones = src.max_stones,
		max_legal_per_stone = src.max_legal_per_stone,
	}
end

--- @param placement table
--- @return table
local function copy_placement_defaults(placement)
	local out = shallow_copy_table(placement)
	out.weights_pre_selection = shallow_copy_table(placement.weights_pre_selection)
	out.weights_selection = shallow_copy_table(placement.weights_selection)
	if placement.heuristics then
		out.heuristics = copy_heuristics_list(placement.heuristics)
	end
	out.heuristics_pre_selection = {}
	for i = 1, #placement.heuristics_pre_selection do
		out.heuristics_pre_selection[i] = placement.heuristics_pre_selection[i]
	end
	out.heuristics_selection = {}
	for i = 1, #placement.heuristics_selection do
		out.heuristics_selection[i] = placement.heuristics_selection[i]
	end
	out.suggestion = copy_suggestion(placement.suggestion)
	return out
end

--- @param profile table
--- @return table
local function resolved_from_profile(profile)
	local placement = copy_placement_defaults(M.placement)
	merge_section(placement, profile.placement)
	return {
		placement = placement,
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
	game.ai_placement = copy_placement_defaults(M.placement)
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
			local saved_heuristics = game.ai_placement.heuristics
			local placement_override = shallow_copy_table(game.ai_placement)
			placement_override.heuristics = nil
			merge_section(resolved.placement, placement_override)
			if saved_heuristics then
				local base = resolved.placement.heuristics or default_legacy_heuristics_list()
				resolved.placement.heuristics = merge_heuristics_list(base, saved_heuristics)
			end
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
	local mode = strategy or "heuristic"
	if mode == "heuristic" then
		if game and game.ai_mcts and game.ai_mcts.enabled == false then
			return false
		end
		if not game or not game.ai_mcts then
			return false
		end
		return mcts.enabled == true and (mcts.iterations or 0) > 0
	end
	if mode == "mcts" then
		return mcts.enabled ~= false and (mcts.iterations or 0) > 0
	end
	return mcts.enabled == true and (mcts.iterations or 0) > 0
end

return M
