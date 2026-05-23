--- Projected match-score delta for a legal stone placement (no ``resolve_round``).
--- Candidate shape for dual suggest: ``{ stone_id, row, col, match_score = delta }``.
--- @module ai.scoring.placement_match_score

local board = require("board")
local config = require("config")
local conditions = require("objects.conditions")
local effect_registry = require("effect_registry")
local match_scoring = require("ai.scoring")
local stone_placement_effects = require("ai.scoring.stone_placement_effects")
local rules = require("rules")
local synergy = require("ai.heuristics.synergy")
local territory = require("single_game.resolver.territory")

local M = {}

--- @param conditions_list table|nil
--- @return boolean
local function triggers_on_stone_placement(conditions_list)
	if not conditions_list then
		return false
	end
	for i = 1, #conditions_list do
		local c = conditions_list[i]
		if c and c.condition_name == "stone_tag_just_added" then
			return true
		end
	end
	return false
end

--- @param b table
--- @param territory_mode string|nil
--- @param owner_key "B"|"W"
--- @return integer
local function weighted_territory_for_owner(b, territory_mode, owner_key)
	local grid, _sources, territory_value = territory.compute_from_board(b, territory_mode)
	local me_stone = owner_key == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
	local total = 0
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			if board.is_empty(b[r][c]) and grid[r][c] == me_stone then
				total = total + ((territory_value[r] and territory_value[r][c]) or 1)
			end
		end
	end
	return total
end

--- @param game table
--- @return table
local function scores_snapshot_from_game(game)
	local black = game.players.black.score
	local white = game.players.white.score
	return {
		turn_bonus = { B = black.turn_bonus or 1, W = white.turn_bonus or 1 },
		territory = { B = black.territory or 0, W = white.territory or 0 },
		points = { B = black.points or 1, W = white.points or 1 },
		plus_mult = { B = black.plus_mult or 1, W = white.plus_mult or 1 },
		x_mult = { B = black.x_mult or 1, W = white.x_mult or 1 },
	}
end

--- @param scores table
--- @param owner "B"|"W"
--- @return table
local function player_score_from_scores(scores, owner)
	return {
		score = {
			turn_bonus = scores.turn_bonus[owner],
			territory = scores.territory[owner],
			points = scores.points[owner],
			plus_mult = scores.plus_mult[owner],
			x_mult = scores.x_mult[owner],
		},
	}
end

--- @param view table
--- @param trial_board table
--- @param stone_id string
--- @return table
local function build_projection_state(view, trial_board, stone_id)
	local game = view:raw_game()
	local actor = view:actor()
	local owner = view:owner_key()
	local resolved = stone_placement_effects.resolved_for_stone_id(stone_id, game, actor)
	return {
		board = trial_board,
		to_play = actor,
		turn_number = game.turn_number,
		round_number = game.round_number,
		players = game.players,
		temporary_stances = game.temporary_stances or {},
		just_played = {},
		played_cards = {},
		active_effects = game.active_effects or {},
		rng = game.rng,
		scores = scores_snapshot_from_game(game),
		round_stone_effects = {
			{
				owner = owner,
				stone_type = stone_id,
				effects = stone_placement_effects.round_effect_defs(resolved),
			},
		},
		resolution = {},
	}
end

--- @param resolved_effects table
--- @param scratch table
--- @param owner "B"|"W"
--- @return nil
local function apply_resolved_stone_effects(resolved_effects, scratch, owner)
	for i = 1, #resolved_effects do
		local resolved = resolved_effects[i]
		if resolved and resolved.apply then
			resolved.apply(scratch, owner)
		end
	end
end

--- @param view table
--- @param scratch table
--- @param owner "B"|"W"
--- @return nil
local function apply_placement_stance_effects(view, scratch, owner)
	local stance_ids = synergy.active_stance_def_ids(view)
	for i = 1, #stance_ids do
		local stance = { type = stance_ids[i], owner = owner }
		local generated = effect_registry.stances.resolve(stance, scratch)
		for j = 1, #generated do
			local effect = generated[j]
			local phase = effect.phase
			if (effect.sub == "points" or effect.sub == "mult") and triggers_on_stone_placement(effect.conditions) then
				if conditions.eval_all(effect.conditions, scratch) and effect.apply then
					effect.apply(scratch)
				end
			end
		end
	end
end

--- @param view table
--- @param trial_board table
--- @param stone_id string
--- @return number
local function projected_match_score(view, trial_board, stone_id)
	local owner = view:owner_key()
	local game = view:raw_game()
	local scratch = build_projection_state(view, trial_board, stone_id)
	scratch.scores.territory[owner] = weighted_territory_for_owner(trial_board, view:territory_mode(), owner)
	local resolved = stone_placement_effects.resolved_for_stone_id(stone_id, game, view:actor())
	apply_resolved_stone_effects(resolved, scratch, owner)
	apply_placement_stance_effects(view, scratch, owner)
	return match_scoring.match_score_total(player_score_from_scores(scratch.scores, owner))
end

--- @param view table
--- @param stone_id string
--- @param row integer
--- @param col integer
--- @return number|nil delta post-place minus baseline; nil if illegal
function M.score_delta(view, stone_id, row, col)
	local b = view:board()
	local ok, trial_board = rules.try_play(b, row, col, view:stone_color(), view:ko_ban(), stone_id)
	if not ok then
		return nil
	end
	local baseline = match_scoring.match_score_total(view:player())
	local post = projected_match_score(view, trial_board, stone_id)
	return post - baseline
end

--- @param view table
--- @param candidates table[] { stone_id, row, col }
--- @return table[] { stone_id, row, col, match_score }
function M.score_candidates(view, candidates)
	local out = {}
	for i = 1, #candidates do
		local c = candidates[i]
		local delta = M.score_delta(view, c.stone_id, c.row, c.col)
		if delta ~= nil then
			out[#out + 1] = {
				stone_id = c.stone_id,
				row = c.row,
				col = c.col,
				match_score = delta,
			}
		end
	end
	return out
end

--- @param view table
--- @param scored table[] entries with ``match_score``
--- @param n integer
--- @return table[]
function M.top_by_match_score(scored, n)
	local copy = {}
	for i = 1, #scored do
		copy[i] = scored[i]
	end
	table.sort(copy, function(a, b)
		if a.match_score ~= b.match_score then
			return a.match_score > b.match_score
		end
		if a.stone_id ~= b.stone_id then
			return a.stone_id < b.stone_id
		end
		if a.row ~= b.row then
			return a.row < b.row
		end
		return a.col < b.col
	end)
	local limit = n
	if limit <= 0 or limit > #copy then
		limit = #copy
	end
	local out = {}
	for i = 1, limit do
		out[i] = copy[i]
	end
	return out
end

return M
