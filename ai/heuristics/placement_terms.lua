--- Registry of full-tier placement heuristic terms (config-driven enable + weights).
--- @module ai.heuristics.placement_terms

local features = require("ai.board_analysis.features")
local goals = require("ai.heuristics.goals")

local M = {}

local function term_enabled(heuristics, id)
	for i = 1, #heuristics do
		local entry = heuristics[i]
		if entry.id == id then
			return entry.enabled ~= false
		end
	end
	return false
end

local TERMS = {}

TERMS.delta_territory_me = {
	id = "delta_territory_me",
	weight_key = "delta_territory_me",
	contribute = function(ctx)
		return ctx.delta_me
	end,
}

TERMS.delta_captures = {
	id = "delta_captures",
	weight_key = "delta_captures",
	contribute = function(ctx)
		return ctx.captures
	end,
}

TERMS.delta_enclosure_inside = {
	id = "delta_enclosure_inside",
	weight_key = "delta_enclosure_inside",
	contribute = function(ctx)
		return math.max(0, ctx.delta_inside)
	end,
}

TERMS.closes_region = {
	id = "closes_region",
	weight_key = "closes_region",
	contribute = function(ctx)
		return ctx.closes_region and 1 or 0
	end,
}

TERMS.frontier = {
	id = "frontier",
	weight_key = "frontier",
	contribute = function(ctx)
		if features.is_placement_frontier(ctx.b, ctx.row, ctx.col, ctx.player, ctx.walls, ctx.owner_key) then
			return 1
		end
		return 0
	end,
}

TERMS.contested_pressure = {
	id = "contested_pressure",
	weight_key = "contested_pressure",
	contribute = function(ctx)
		if ctx.before.territory_contested > 0 and ctx.delta_me > 0 then
			return 1
		end
		return 0
	end,
}

TERMS.weak_boundary_penalty = {
	id = "weak_boundary_penalty",
	weight_key = "weak_boundary_penalty",
	contribute = function(ctx)
		local delta = ctx.after.weak_boundary_cells - ctx.before.weak_boundary_cells
		if delta > 0 then
			return delta
		end
		return 0
	end,
}

TERMS.self_fill_penalty = {
	id = "self_fill_penalty",
	weight_key = "self_fill_penalty",
	contribute = function(ctx)
		if ctx.captures == 0
			and not features.is_placement_frontier(ctx.b, ctx.row, ctx.col, ctx.player, ctx.walls, ctx.owner_key)
			and ctx.delta_me <= 0 then
			return 1
		end
		return 0
	end,
}

TERMS.goals_bonus = {
	id = "goals_bonus",
	unweighted = true,
	contribute = function(ctx, candidate)
		return goals.candidate_bonus(ctx.view, candidate)
	end,
}

--- Weighted sum of enabled terms for one side (excludes ``goals_bonus``).
--- @param ctx table
--- @param placement_cfg table resolved ``placement`` from ``ai.config.for_game``
--- @return number
function M.sum_side(ctx, placement_cfg)
	local weights = placement_cfg.weights
	local heuristics = placement_cfg.heuristics
	local total = 0
	for i = 1, #heuristics do
		local entry = heuristics[i]
		if entry.enabled ~= false then
			local term = TERMS[entry.id]
			if term and term.id ~= "goals_bonus" then
				local w = weights[term.weight_key] or 0
				total = total + w * term.contribute(ctx)
			end
		end
	end
	return total
end

--- @param ctx table
--- @param placement_cfg table
--- @param candidate table
--- @return number
function M.goals_bonus(ctx, placement_cfg, candidate)
	if not term_enabled(placement_cfg.heuristics, "goals_bonus") then
		return 0
	end
	return TERMS.goals_bonus.contribute(ctx, candidate)
end

--- @param heuristics table[]
--- @param id string
--- @return boolean
function M.is_enabled(heuristics, id)
	return term_enabled(heuristics, id)
end

return M
