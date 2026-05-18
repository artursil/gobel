--- Shared per-candidate context for full placement heuristic evaluation (one ``try_play``).
--- @module ai.heuristics.placement_context

local config = require("config")
local features = require("ai.board_analysis.features")
local snapshot = require("ai.board_analysis.snapshot")
local territory_analysis = require("ai.board_analysis.territory")
local rules = require("rules")

local M = {}

--- @param view table
--- @param before table
--- @param after table
--- @param b table
--- @param row integer
--- @param col integer
--- @param player integer
--- @param owner_key "B"|"W"
--- @param walls table|nil
--- @param captures integer
--- @param trial_board table
--- @param ko table|nil
--- @return table ctx
local function make_ctx(view, before, after, b, row, col, player, owner_key, walls, captures, trial_board, ko)
	local delta_me = after.territory_owned_me - before.territory_owned_me
	local delta_inside = after.largest_enclosure_inside_me - before.largest_enclosure_inside_me
	local closes_region = delta_inside > 0 or (delta_me > 0 and after.territory_contested < before.territory_contested)
	return {
		view = view,
		row = row,
		col = col,
		stone_id = nil,
		b = b,
		player = player,
		owner_key = owner_key,
		mode = view:territory_mode(),
		before = before,
		after = after,
		captures = captures,
		trial_board = trial_board,
		ko = ko,
		walls = walls,
		delta_me = delta_me,
		delta_inside = delta_inside,
		closes_region = closes_region,
	}
end

--- @param view table
--- @param row integer
--- @param col integer
--- @param stone_id string
--- @param base_features table|nil
--- @param territory_before table|nil
--- @return table|nil ctx
function M.build(view, row, col, stone_id, base_features, territory_before)
	local b = view:board()
	local player = view:stone_color()
	local owner_key = view:owner_key()
	local mode = view:territory_mode()
	local ok, trial_board, new_ko, captures = rules.try_play(b, row, col, player, view:ko_ban(), stone_id)
	if not ok then
		return nil
	end
	local counts_before = territory_before
		or (base_features and {
			owned_me = base_features.territory_owned_me,
			owned_opp = base_features.territory_owned_opp,
			contested = base_features.territory_contested,
			grid = base_features._territory_grid,
			sources = nil,
		})
	local before = base_features
		or features.build(b, view:ko_ban(), owner_key, mode, player, counts_before, nil)
	local after_ko = snapshot.clone_ko(new_ko)
	local after_counts = territory_analysis.analyze(trial_board, mode, owner_key)
	local after = features.build(trial_board, after_ko, owner_key, mode, player, after_counts, before._walls)
	local ctx = make_ctx(view, before, after, b, row, col, player, owner_key, before._walls, captures, trial_board, after_ko)
	ctx.stone_id = stone_id
	return ctx
end

--- Opponent perspective on the same trial board (margin mode); captures treated as 0 for opp.
--- @param main_ctx table
--- @return table ctx
function M.build_opponent(main_ctx)
	local view = main_ctx.view
	local b = main_ctx.b
	local mode = main_ctx.mode
	local owner_key = main_ctx.owner_key == config.OWNER_BLACK and config.OWNER_WHITE or config.OWNER_BLACK
	local player = main_ctx.player == config.STONE_BLACK and config.STONE_WHITE or config.STONE_BLACK
	local terr_opp_before = territory_analysis.analyze(b, mode, owner_key)
	local before_opp = features.build(b, view:ko_ban(), owner_key, mode, player, terr_opp_before, main_ctx.walls)
	local after_opp_counts = territory_analysis.analyze(main_ctx.trial_board, mode, owner_key)
	local after_opp = features.build(
		main_ctx.trial_board,
		main_ctx.ko,
		owner_key,
		mode,
		player,
		after_opp_counts,
		main_ctx.walls
	)
	local ctx = make_ctx(
		view,
		before_opp,
		after_opp,
		b,
		main_ctx.row,
		main_ctx.col,
		player,
		owner_key,
		main_ctx.walls,
		0,
		main_ctx.trial_board,
		main_ctx.ko
	)
	ctx.stone_id = main_ctx.stone_id
	return ctx
end

--- @param ctx table
--- @param score number
--- @return table candidate
function M.to_candidate(ctx, score)
	return {
		row = ctx.row,
		col = ctx.col,
		delta_territory_me = ctx.delta_me,
		delta_captures = ctx.captures,
		delta_enclosure_inside = ctx.delta_inside,
		closes_region = ctx.closes_region,
		score = score,
	}
end

return M
