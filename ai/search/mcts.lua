--- Shallow MCTS over top-K placement candidates (root children only, rollout alternation).
---
--- Flow: root (current board) → K child arms (one per candidate) → UCT select arm →
--- rollout (opponent greedy / AI sampled) → leaf ``evaluate_position`` → backprop value in [0,1].
--- @module ai.search.mcts

local evaluate = require("ai.board_analysis.evaluate")
local enclosure = require("single_game.resolver.enclosure")
local features = require("ai.board_analysis.features")
local match_view = require("ai.adapters.match_view")
local ai_config = require("ai.config")
local rules = require("rules")
local snapshot = require("ai.board_analysis.snapshot")

local M = {}

--- @param child table
--- @param parent_visits integer
--- @param exploration_c number
--- @return number
local function uct_value(child, parent_visits, exploration_c)
	if child.visits == 0 then
		return math.huge
	end
	local q = child.total_value / child.visits
	return q + exploration_c * math.sqrt(math.log(math.max(1, parent_visits)) / child.visits)
end

--- @param children table[]
--- @param parent_visits integer
--- @param exploration_c number
--- @return table|nil
local function select_child(children, parent_visits, exploration_c)
	for i = 1, #children do
		if children[i].visits == 0 then
			return children[i]
		end
	end
	local best = children[1]
	local best_uct = uct_value(best, parent_visits, exploration_c)
	for i = 2, #children do
		local u = uct_value(children[i], parent_visits, exploration_c)
		if u > best_uct then
			best = children[i]
			best_uct = u
		end
	end
	return best
end

--- @param view table
--- @param actor "black"|"white"
--- @return string|nil
local function stone_id_for_actor(view, actor)
	local actor_view = match_view.for_actor(view:raw_game(), actor)
	local id = actor_view:selected_stone_id()
	if id then
		return id
	end
	local playable = actor_view:playable_stones()
	if #playable > 0 then
		return playable[1]
	end
	return nil
end

--- @param b table
--- @param player integer
--- @param ko table|nil
--- @param stone_id string
--- @param stone_color integer
--- @param walls table|nil
--- @param owner_key "B"|"W"
--- @return table[] frontier moves
local function fast_frontier_moves(b, player, ko, stone_id, stone_color, walls, owner_key)
	local legal = rules.all_legal_moves(b, player, ko, stone_id)
	local out = {}
	for i = 1, #legal do
		local row, col = legal[i][1], legal[i][2]
		local ok, _, _, captures = rules.try_play(b, row, col, player, ko, stone_id)
		if ok and (captures > 0 or features.is_placement_frontier(b, row, col, stone_color, walls, owner_key)) then
			out[#out + 1] = { row = row, col = col, captures = captures }
		end
	end
	return out
end

--- @param view table
--- @param board table
--- @param ko table|nil
--- @param actor "black"|"white"
--- @param stone_id string
--- @param walls table|nil
--- @return table|nil move
local function pick_rollout_move_fast(view, board, ko, actor, stone_id, walls)
	local game = view:raw_game()
	local sim_view = match_view.with_board(match_view.for_actor(game, actor), board, ko)
	local player = sim_view:stone_color()
	local owner_key = sim_view:owner_key()
	walls = walls or enclosure.extract_walls(board)
	local pool = fast_frontier_moves(board, player, ko, stone_id, player, walls, owner_key)
	if #pool == 0 then
		return nil
	end
	local pick = pool[sim_view:rng_next_int(#pool)]
	return { row = pick.row, col = pick.col }
end

--- @param view table
--- @param board table
--- @param ko table|nil
--- @param actor "black"|"white"
--- @param stone_id string
--- @param walls table|nil
--- @return table|nil move
local function pick_opponent_move_fast(view, board, ko, actor, stone_id, walls)
	local game = view:raw_game()
	local sim_view = match_view.with_board(match_view.for_actor(game, actor), board, ko)
	local player = sim_view:stone_color()
	local owner_key = sim_view:owner_key()
	walls = walls or enclosure.extract_walls(board)
	local pool = fast_frontier_moves(board, player, ko, stone_id, player, walls, owner_key)
	if #pool == 0 then
		return nil
	end
	table.sort(pool, function(a, b)
		return a.captures > b.captures
	end)
	local n = math.min(3, #pool)
	local pick = pool[sim_view:rng_next_int(n)]
	return { row = pick.row, col = pick.col }
end

--- @param view table
--- @param board table
--- @param ko table|nil
--- @param ai_actor "black"|"white"
--- @param ai_stone string
--- @param opts table
--- @return number normalized [0,1]
local function rollout(view, board, ko, ai_actor, ai_stone, opts)
	local game = view:raw_game()
	local opp_actor = match_view.opponent_actor(ai_actor)
	local opp_stone = stone_id_for_actor(view, opp_actor)
	local walls = opts.walls
	local to_move = opp_actor
	local depth = 0
	while depth < opts.max_rollout_depth do
		local stone_id = (to_move == ai_actor) and ai_stone or opp_stone
		if not stone_id then
			break
		end
		local move
		if to_move == ai_actor then
			move = pick_rollout_move_fast(view, board, ko, ai_actor, stone_id, walls)
		else
			move = pick_opponent_move_fast(view, board, ko, opp_actor, stone_id, walls)
		end
		if not move then
			break
		end
		local player = (to_move == ai_actor) and view:stone_color()
			or match_view.for_actor(game, opp_actor):stone_color()
		local ok, trial, new_ko = rules.try_play(board, move.row, move.col, player, ko, stone_id)
		if not ok then
			break
		end
		board = trial
		ko = snapshot.clone_ko(new_ko)
		walls = enclosure.extract_walls(board)
		to_move = match_view.opponent_actor(to_move)
		depth = depth + 1
	end
	local ai_owner = view:owner_key()
	local opp_owner = match_view.for_actor(game, opp_actor):owner_key()
	local ai_color = view:stone_color()
	local opp_color = match_view.for_actor(game, opp_actor):stone_color()
	local ai_eval = evaluate.fast_evaluate_position(board, ai_color, ai_owner, walls)
	local opp_eval = evaluate.fast_evaluate_position(board, opp_color, opp_owner, walls)
	return evaluate.normalize_result(ai_eval, opp_eval)
end

--- @param children table[]
--- @param rng_next fun(integer): integer
--- @return table
local function pick_best_child(children, rng_next)
	local best = children[1]
	local best_mean = best.total_value / best.visits
	for i = 2, #children do
		local child = children[i]
		local mean = child.total_value / child.visits
		if mean > best_mean then
			best = child
			best_mean = mean
		elseif mean == best_mean then
			if child.visits > best.visits then
				best = child
			elseif child.visits == best.visits and rng_next(2) == 2 then
				best = child
			end
		end
	end
	return best
end

--- @param view table
--- @param candidates table[]
--- @param stone_id string
--- @param opts table
--- @return table|nil
local function build_children(view, candidates, stone_id, opts)
	local children = {}
	local board = view:board()
	local ko = view:ko_ban()
	local player = view:stone_color()
	for i = 1, #candidates do
		local move = candidates[i]
		local ok, trial, new_ko = rules.try_play(board, move.row, move.col, player, ko, stone_id)
		if ok then
			children[#children + 1] = {
				row = move.row,
				col = move.col,
				board = trial,
				ko = snapshot.clone_ko(new_ko),
				visits = 0,
				total_value = 0,
			}
		end
	end
	return children
end

--- Shallow MCTS: one tree level (root candidates), UCT + rollout + backprop.
--- @param view table AI match view at root
--- @param candidates table[] { row, col }
--- @param opts table|nil merged ai_mcts + cached walls / territory_before
--- @return table|nil { row, col }
function M.choose_placement(view, candidates, call_opts)
	local merged = ai_config.for_game(view:raw_game()).mcts
	local opts = {
		enabled = merged.enabled,
		iterations = merged.iterations,
		max_rollout_depth = merged.max_rollout_depth,
		exploration_c = merged.exploration_c,
		fast_rollout = merged.fast_rollout,
		max_decision_ms = merged.max_decision_ms,
	}
	if call_opts then
		for k, v in pairs(call_opts) do
			opts[k] = v
		end
	end
	if not ai_config.mcts_should_run(view:raw_game(), view:ai_strategy()) then
		return nil
	end
	if not candidates or #candidates == 0 then
		return nil
	end
	if (opts.iterations or 0) <= 0 then
		return nil
	end

	local stone_id = view:selected_stone_id() or stone_id_for_actor(view, view:actor())
	if not stone_id then
		return nil
	end

	opts.walls = opts.walls or enclosure.extract_walls(view:board())
	local game = view:raw_game()
	local ai_actor = view:actor()
	local children = build_children(view, candidates, stone_id, opts)
	if #children == 0 then
		return nil
	end

	local parent_visits = 0
	local deadline = nil
	if opts.max_decision_ms and opts.max_decision_ms > 0 then
		deadline = os.clock() + opts.max_decision_ms * 0.001
	end
	for _ = 1, opts.iterations do
		if deadline and os.clock() >= deadline then
			break
		end
		local child = select_child(children, parent_visits, opts.exploration_c)
		local value = rollout(view, child.board, child.ko, ai_actor, stone_id, opts)
		child.visits = child.visits + 1
		child.total_value = child.total_value + value
		parent_visits = parent_visits + 1
	end
	if parent_visits == 0 then
		return nil
	end

	local best = pick_best_child(children, function(max_value)
		return view:rng_next_int(max_value)
	end)
	return { row = best.row, col = best.col }
end

return M
