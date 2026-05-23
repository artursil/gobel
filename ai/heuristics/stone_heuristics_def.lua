--- Canonical stone-placement heuristic term definitions (``contribute(ctx)`` only; weights in ``ai.config``).
--- @module ai.heuristics.stone_heuristics_def

local config = require("config")
local features = require("ai.board_analysis.features")
local goals = require("ai.heuristics.goals")
local pattern_proximity = require("ai.heuristics.pattern_proximity")

local M = {}

--- @param list string[]
--- @param id string
--- @return boolean
local function term_in_list(list, id)
	for i = 1, #list do
		if list[i] == id then
			return true
		end
	end
	return false
end

--- @param heuristics table[]|nil legacy ``{ id, enabled }`` list
--- @param id string
--- @return boolean
local function legacy_term_enabled(heuristics, id)
	if not heuristics then
		return true
	end
	for i = 1, #heuristics do
		local entry = heuristics[i]
		if entry.id == id then
			return entry.enabled ~= false
		end
	end
	return true
end

--- @param list string[]
--- @param heuristics table[]|nil
--- @return string[]
local function filter_list_by_legacy(list, heuristics)
	if not heuristics then
		return list
	end
	local out = {}
	for i = 1, #list do
		local id = list[i]
		if legacy_term_enabled(heuristics, id) then
			out[#out + 1] = id
		end
	end
	return out
end

local TERMS = {}

--- Empty territory cells gained for the acting player after this play.
TERMS.delta_territory_me = {
	id = "delta_territory_me",
	weight_key = "delta_territory_me",
	contribute = function(ctx)
		return ctx.delta_me
	end,
}

--- Stones captured by this placement (from ``try_play``).
TERMS.delta_captures = {
	id = "delta_captures",
	weight_key = "delta_captures",
	contribute = function(ctx)
		return ctx.captures
	end,
}

--- Increase in cells inside the player's largest enclosure.
TERMS.delta_enclosure_inside = {
	id = "delta_enclosure_inside",
	weight_key = "delta_enclosure_inside",
	contribute = function(ctx)
		return math.max(0, ctx.delta_inside)
	end,
}

--- Whether the move closes or secures a region (enclosure growth or contested shrink with gain).
TERMS.closes_region = {
	id = "closes_region",
	weight_key = "closes_region",
	contribute = function(ctx)
		return ctx.closes_region and 1 or 0
	end,
}

--- Whether the intersection is on the placement frontier (wall-aware).
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

--- Bonus when contested territory existed before and the player gained owned cells.
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

--- Penalty per new weak-boundary cell after the play.
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

--- Penalty for interior fill with no capture, frontier contact, or territory gain.
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

--- Whether empty-cell territory ownership counts changed (prescore / movegen tier).
TERMS.territory_owner_change = {
	id = "territory_owner_change",
	weight_key = "territory_owner_change",
	contribute = function(ctx)
		return ctx.territory_owner_changed and 1 or 0
	end,
}

--- ``x_stone`` in hand and within 2 moves of completing an X for self.
TERMS.x_stone_near_complete = {
	id = "x_stone_near_complete",
	weight_key = "x_stone_near_complete",
	contribute = function(ctx)
		if ctx.stone_id ~= "x_stone" then
			return 0
		end
		local moves = pattern_proximity.moves_to_complete_x(ctx.b, ctx.player, 2)
		if moves <= 2 then
			return 3 - moves
		end
		return 0
	end,
}

--- Blocking opponent X completion within 2 moves (any stone).
TERMS.x_stone_block_opponent_x = {
	id = "x_stone_block_opponent_x",
	weight_key = "x_stone_block_opponent_x",
	contribute = function(ctx)
		local opp = ctx.player == config.STONE_BLACK and config.STONE_WHITE or config.STONE_BLACK
		if pattern_proximity.is_blocking_cell(ctx.b, ctx.row, ctx.col, opp, "x", 2) then
			return 1
		end
		return 0
	end,
}

--- ``plus_stone`` in hand and within 2 moves of completing a + for self.
TERMS.plus_stone_near_complete = {
	id = "plus_stone_near_complete",
	weight_key = "plus_stone_near_complete",
	contribute = function(ctx)
		if ctx.stone_id ~= "plus_stone" then
			return 0
		end
		local moves = pattern_proximity.moves_to_complete_plus(ctx.b, ctx.player, 2)
		if moves <= 2 then
			return 3 - moves
		end
		return 0
	end,
}

--- Blocking opponent + completion within 2 moves (any stone).
TERMS.plus_stone_block_opponent_plus = {
	id = "plus_stone_block_opponent_plus",
	weight_key = "plus_stone_block_opponent_plus",
	contribute = function(ctx)
		local opp = ctx.player == config.STONE_BLACK and config.STONE_WHITE or config.STONE_BLACK
		if pattern_proximity.is_blocking_cell(ctx.b, ctx.row, ctx.col, opp, "plus", 2) then
			return 1
		end
		return 0
	end,
}

--- Strategic goal bonus from ``goals.candidate_bonus`` (selection tier, unweighted).
TERMS.goals_bonus = {
	id = "goals_bonus",
	unweighted = true,
	contribute = function(ctx, candidate)
		return goals.candidate_bonus(ctx.view, candidate)
	end,
}

M.TERMS = TERMS

--- @param ctx table
--- @param placement_cfg table
--- @param term_ids string[]
--- @param weights table
--- @return number
local function sum_terms(ctx, placement_cfg, term_ids, weights)
	local heuristics = placement_cfg.heuristics
	local filtered = filter_list_by_legacy(term_ids, heuristics)
	local total = 0
	for i = 1, #filtered do
		local id = filtered[i]
		local term = TERMS[id]
		if term and not term.unweighted then
			local w = weights[term.weight_key] or 0
			total = total + w * term.contribute(ctx)
		end
	end
	return total
end

--- Fast prescore tier: captures, frontier, optional territory-owner flip (no full feature deltas).
--- @param ctx table placement context from ``placement_context.build`` or minimal cheap ctx
--- @param placement_cfg table resolved ``placement`` from ``ai.config.for_game``
--- @return number
function M.sum_pre_selection(ctx, placement_cfg)
	return sum_terms(ctx, placement_cfg, placement_cfg.heuristics_pre_selection, placement_cfg.weights_pre_selection)
end

--- Full selection tier: territory, enclosure, penalties; excludes ``goals_bonus``.
--- @param ctx table
--- @param placement_cfg table
--- @return number
function M.sum_selection(ctx, placement_cfg)
	return sum_terms(ctx, placement_cfg, placement_cfg.heuristics_selection, placement_cfg.weights_selection)
end

--- Strategic goal bonus (selection tier only; unweighted).
--- @param ctx table
--- @param placement_cfg table
--- @param candidate table
--- @return number
function M.goals_bonus(ctx, placement_cfg, candidate)
	if not term_in_list(placement_cfg.heuristics_selection, "goals_bonus") then
		return 0
	end
	if not legacy_term_enabled(placement_cfg.heuristics, "goals_bonus") then
		return 0
	end
	return TERMS.goals_bonus.contribute(ctx, candidate)
end

--- @param heuristics table[]|nil
--- @param id string
--- @return boolean
function M.is_enabled(heuristics, id)
	return legacy_term_enabled(heuristics, id)
end

return M
