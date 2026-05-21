--- Legal placement move generation and top-K filtering.
--- @module ai.movegen.placement_candidates

local ai_config = require("ai.config")
local board = require("board")
local config = require("config")
local enclosure = require("single_game.resolver.enclosure")
local features = require("ai.board_analysis.features")
local rules = require("rules")
local territory_analysis = require("ai.board_analysis.territory")

local M = {}

--- @param moves table[]
--- @param row integer
--- @param col integer
--- @return boolean
local function contains_move(moves, row, col)
	for i = 1, #moves do
		if moves[i].row == row and moves[i].col == col then
			return true
		end
	end
	return false
end

--- @param list table[]
--- @param move table
--- @return nil
local function add_unique(list, move)
	if not contains_move(list, move.row, move.col) then
		list[#list + 1] = move
	end
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param player integer
--- @param ko table|nil
--- @param stone_id string
--- @return boolean
local function is_capture(b, row, col, player, ko, stone_id)
	local ok, _trial, _new_ko, captures = rules.try_play(b, row, col, player, ko, stone_id)
	return ok and captures > 0
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param player integer
--- @param ko table|nil
--- @param stone_id string
--- @param territory_before table
--- @param mode string|nil
--- @param owner_key "B"|"W"
--- @return boolean
local function changes_territory_owner(b, row, col, player, ko, stone_id, territory_before, mode, owner_key)
	local ok, trial = rules.try_play(b, row, col, player, ko, stone_id)
	if not ok then
		return false
	end
	local after = territory_analysis.analyze(trial, mode, owner_key)
	return after.owned_me ~= territory_before.owned_me or after.owned_opp ~= territory_before.owned_opp
end

--- @param move table
--- @param b table
--- @param player integer
--- @param ko table|nil
--- @param stone_id string
--- @param owner_key "B"|"W"
--- @param walls table
--- @param territory_before table
--- @param mode string|nil
--- @param weights_pre table
--- @return number
local function cheap_prescore(move, b, player, ko, stone_id, owner_key, walls, territory_before, mode, weights_pre)
	local row, col = move.row, move.col
	local score = 0
	if is_capture(b, row, col, player, ko, stone_id) then
		score = score + (weights_pre.delta_captures or 0)
	end
	if features.is_placement_frontier(b, row, col, player, walls, owner_key) then
		score = score + (weights_pre.frontier or 0)
	end
	if changes_territory_owner(b, row, col, player, ko, stone_id, territory_before, mode, owner_key) then
		score = score + (weights_pre.territory_owner_change or 0)
	end
	return score
end

--- @param row integer
--- @param col integer
--- @param b table
--- @param player integer
--- @param ko table|nil
--- @param stone_id string
--- @param owner_key "B"|"W"
--- @param walls table
--- @param territory_before table
--- @param mode string|nil
--- @return number
function M.cheap_prescore_move(row, col, b, player, ko, stone_id, owner_key, walls, territory_before, mode, weights_pre)
	return cheap_prescore(
		{ row = row, col = col },
		b,
		player,
		ko,
		stone_id,
		owner_key,
		walls,
		territory_before,
		mode,
		weights_pre or ai_config.placement.weights_pre_selection
	)
end

--- @param scored table[]
--- @param k integer
--- @param rng_next fun(integer): integer
--- @return table[]
local function take_top_k_with_tie_shuffle(scored, k, rng_next)
	local out = {}
	local i = 1
	while #out < k and i <= #scored do
		local prescore = scored[i].prescore
		local bucket = {}
		while i <= #scored and scored[i].prescore == prescore do
			bucket[#bucket + 1] = scored[i]
			i = i + 1
		end
		while #bucket > 0 and #out < k do
			local pick = rng_next(#bucket)
			out[#out + 1] = table.remove(bucket, pick)
		end
	end
	return out
end

--- @param view table
--- @param stone_id string
--- @param k integer|nil
--- @param territory_before table|nil cached territory counts for ``view:board()``
--- @param walls table|nil cached ``enclosure.extract_walls`` for current board
--- @param skip_territory_probe boolean|nil when true, omit ``changes_territory_owner`` filter (faster)
--- @return table[] moves { row, col }
function M.top_candidates(view, stone_id, k, territory_before, walls, skip_territory_probe)
	local placement_cfg = ai_config.for_game(view:raw_game()).placement
	k = k or placement_cfg.candidate_k
	local b = view:board()
	local player = view:stone_color()
	local ko = view:ko_ban()
	local owner_key = view:owner_key()
	local mode = view:territory_mode()
	territory_before = territory_before or territory_analysis.analyze(b, mode, owner_key)
	walls = walls or enclosure.extract_walls(b)
	local legal = rules.all_legal_moves(b, player, ko, stone_id)
	if #legal == 0 then
		return {}
	end

	local filtered = {}
	for i = 1, #legal do
		local row, col = legal[i][1], legal[i][2]
		local move = { row = row, col = col }
		if is_capture(b, row, col, player, ko, stone_id) then
			add_unique(filtered, move)
		elseif features.is_placement_frontier(b, row, col, player, walls, owner_key) then
			add_unique(filtered, move)
		elseif not skip_territory_probe
			and changes_territory_owner(b, row, col, player, ko, stone_id, territory_before, mode, owner_key) then
			add_unique(filtered, move)
		end
	end
	if #filtered == 0 then
		for i = 1, #legal do
			filtered[#filtered + 1] = { row = legal[i][1], col = legal[i][2] }
		end
	end

	if not placement_cfg.prescore_enabled then
		local out = {}
		local n = math.min(k, #filtered)
		for i = 1, n do
			out[#out + 1] = { row = filtered[i].row, col = filtered[i].col }
		end
		return out
	end

	local weights_pre = placement_cfg.weights_pre_selection
	local scored = {}
	for i = 1, #filtered do
		local move = filtered[i]
		scored[#scored + 1] = {
			row = move.row,
			col = move.col,
			prescore = cheap_prescore(
				move,
				b,
				player,
				ko,
				stone_id,
				owner_key,
				walls,
				territory_before,
				mode,
				weights_pre
			),
		}
	end
	table.sort(scored, function(a, b_entry)
		return a.prescore > b_entry.prescore
	end)
	local picked = take_top_k_with_tie_shuffle(scored, k, function(max_value)
		return view:rng_next_int(max_value)
	end)
	local out = {}
	for i = 1, #picked do
		out[#out + 1] = { row = picked[i].row, col = picked[i].col }
	end
	return out
end

return M
