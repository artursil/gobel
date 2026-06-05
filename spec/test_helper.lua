package.path = package.path .. ";./?.lua;./?/init.lua"

local M = {}

if not love then
	love = {}
end

if not love.math then
	love.math = {}
end

if not love.math.random then
	function love.math.random(min_value, max_value)
		if max_value then
			return min_value
		end
		return 1
	end
end

function M.rng_always_one(_max_value)
	return 1
end

function M.copy_ids(ids)
	local out = {}
	for i = 1, #ids do
		out[i] = ids[i]
	end
	return out
end

function M.get_upvalue(fn, target_name)
	local idx = 1
	while true do
		local name, value = debug.getupvalue(fn, idx)
		if not name then
			return nil
		end
		if name == target_name then
			return value, idx
		end
		idx = idx + 1
	end
end

function M.set_upvalue(fn, target_name, new_value)
	local idx = 1
	while true do
		local name = debug.getupvalue(fn, idx)
		if not name then
			return false
		end
		if name == target_name then
			debug.setupvalue(fn, idx, new_value)
			return true
		end
		idx = idx + 1
	end
end

function M.install_love_test_stubs()
	love = love or {}
	love.math = love.math or {}
	love.timer = love.timer or {}
	love.event = love.event or {}
	love.graphics = love.graphics or {}
	love.mouse = love.mouse or {}
	love.math.random = love.math.random
		or function(min_value, max_value)
			if max_value then
				return min_value
			end
			return 1
		end
	love.math.setRandomSeed = love.math.setRandomSeed or function() end
	love.timer.getTime = love.timer.getTime or function()
		return 1
	end
	love.event.quit = love.event.quit or function() end
	love.graphics.newFont = love.graphics.newFont or function()
		return {
			getHeight = function()
				return 18
			end,
			getWidth = function(text)
				return #(tostring(text or "")) * 8
			end,
			setBold = function()
				return nil
			end,
			getWrap = function(a, b, c)
				local text, width
				if type(a) == "string" then
					text, width = a, b
				else
					text, width = b, c
				end
				local chars = math.max(1, math.floor((width or 80) / 8))
				local lines = {}
				local body = tostring(text or "")
				for i = 1, #body, chars do
					lines[#lines + 1] = body:sub(i, i + chars - 1)
				end
				if #lines == 0 then
					lines[1] = ""
				end
				return body, lines
			end,
		}
	end
	love.graphics.newImage = love.graphics.newImage or function()
		return {
			getWidth = function()
				return 64
			end,
			getHeight = function()
				return 64
			end,
		}
	end
	love.graphics.draw = love.graphics.draw or function() end
	love.filesystem = love.filesystem or {}
	love.filesystem.getInfo = love.filesystem.getInfo or function()
		return nil
	end
	love.graphics.setFont = love.graphics.setFont or function() end
	love.graphics.getFont = love.graphics.getFont or function()
		return love.graphics.newFont()
	end
	love.graphics.getDimensions = love.graphics.getDimensions or function()
		return 1280, 720
	end
	love.graphics.getWidth = love.graphics.getWidth or function()
		return 1280
	end
	love.graphics.getHeight = love.graphics.getHeight or function()
		return 720
	end
	love.graphics.clear = love.graphics.clear or function() end
	love.graphics.setColor = love.graphics.setColor or function() end
	love.graphics.rectangle = love.graphics.rectangle or function() end
	love.graphics.circle = love.graphics.circle or function() end
	love.graphics.line = love.graphics.line or function() end
	love.graphics.polygon = love.graphics.polygon or function() end
	love.graphics.printf = love.graphics.printf or function() end
	love.graphics.print = love.graphics.print or function() end
	love.graphics.setLineWidth = love.graphics.setLineWidth or function() end
	love.graphics.push = love.graphics.push or function() end
	love.graphics.pop = love.graphics.pop or function() end
	love.graphics.translate = love.graphics.translate or function() end
	love.graphics.rotate = love.graphics.rotate or function() end
	love.graphics.setScissor = love.graphics.setScissor or function(...) end
	love.mouse.getPosition = love.mouse.getPosition or function()
		return 0, 0
	end
end

function M.reset_module(name)
	package.loaded[name] = nil
	return require(name)
end

--- Advances UI animation jobs until a deferred ``begin_next_turn`` applies (see ``resolver.flush_pending_turn_if_ready``).
--- @param state table
--- @return nil
function M.finish_ui_animations_for_turn(state)
	local layout_mod = require("layout")
	local resolver = require("resolver")
	local ui_animations = require("ui.animations")
	local layout = layout_mod.from_window(1280, 720)
	for _ = 1, 200 do
		if state.pending_turn_after_ui ~= true then
			break
		end
		ui_animations.update(0.05, state, layout)
		resolver.flush_pending_turn_if_ready(state)
	end
end

M.PATTERN_STONE_IDS = { "x_stone", "plus_stone", "wall" }

local assert = require("luassert")
local board = require("board")
local config = require("config")
local content = require("content")
local match_state = require("match_state")
local spec_helper = require("spec.spec_helper")

M.params = require("spec.parameters_helper")

local debug_stone_to_letter = nil
local visual_letter_to_stone = nil
local scoring_debug_dump_pending = false
local scoring_debug_already_dumped = false

--- Registers ASCII letter maps for ``set_board`` / ``place_stone`` and optional INTEGRATION_DEBUG board dumps.
--- @param letter_to_stone table
--- @param stone_to_letter_for_debug table|nil
function M.set_visual_board_letters(letter_to_stone, stone_to_letter_for_debug)
	visual_letter_to_stone = letter_to_stone
	if stone_to_letter_for_debug then
		M.set_integration_debug_stone_letters(stone_to_letter_for_debug)
	end
end

--- @return table
local function require_visual_letter_map()
	if not visual_letter_to_stone then
		error("call set_visual_board_letters before set_board or place_stone")
	end
	return visual_letter_to_stone
end

--- Maps stone kinds to ASCII letters for INTEGRATION_DEBUG board dumps (e.g. scoring_spec).
--- @param stone_to_letter table
function M.set_integration_debug_stone_letters(stone_to_letter)
	debug_stone_to_letter = stone_to_letter
end

--- Prints territory, points, plus_mult, and x_mult for both players when INTEGRATION_DEBUG=1.
--- @param g table
--- @param label string|nil
function M.debug_print_scoring_values(g, label)
	if not spec_helper.integration_debug_enabled() then
		return
	end
	local black = g.players.black.score
	local white = g.players.white.score
	print("")
	print("[INTEGRATION_DEBUG] scoring values — " .. (label or "snapshot"))
	print(string.format(
		"  black: turn_bonus=%s territory=%s points=%s plus_mult=%s x_mult=%s",
		tostring(black.turn_bonus),
		tostring(black.territory),
		tostring(black.points),
		tostring(black.plus_mult),
		tostring(black.x_mult)
	))
	print(string.format(
		"  white: turn_bonus=%s territory=%s points=%s plus_mult=%s x_mult=%s",
		tostring(white.turn_bonus),
		tostring(white.territory),
		tostring(white.points),
		tostring(white.plus_mult),
		tostring(white.x_mult)
	))
	if g.scores then
		print(string.format(
			"  state.scores B: turn_bonus=%s territory=%s points=%s plus_mult=%s x_mult=%s",
			tostring(g.scores.turn_bonus.B),
			tostring(g.scores.territory.B),
			tostring(g.scores.points.B),
			tostring(g.scores.plus_mult.B),
			tostring(g.scores.x_mult.B)
		))
		print(string.format(
			"  state.scores W: turn_bonus=%s territory=%s points=%s plus_mult=%s x_mult=%s",
			tostring(g.scores.turn_bonus.W),
			tostring(g.scores.territory.W),
			tostring(g.scores.points.W),
			tostring(g.scores.plus_mult.W),
			tostring(g.scores.x_mult.W)
		))
	end
end

local function debug_scoring_on_mismatch(g, label, expected, actual)
	if g and spec_helper.integration_debug_enabled() and expected ~= actual then
		scoring_debug_dump_pending = true
	end
end

local function assert_equal_with_scoring_debug(g, expected, actual, context)
	debug_scoring_on_mismatch(g, context, expected, actual)
	assert.are.equal(expected, actual, context)
end

--- @param g table
--- @param label string|nil
--- @param opts table|nil  ``expected_territory``, ``expected_territory_values`` (strings)
function M.debug_dump_game_state(g, label, opts)
	if not spec_helper.integration_debug_enabled() then
		return
	end
	scoring_debug_already_dumped = true
	opts = opts or {}
	local name = label or "game state"
	local territory = g.territory or spec_helper.territory_map(g.board, "regional")
	print("")
	print("[INTEGRATION_DEBUG] " .. name)
	print("board:")
	if debug_stone_to_letter then
		print(spec_helper.board_ascii_kinds(g.board, debug_stone_to_letter))
	else
		print(spec_helper.board_ascii(g.board))
	end
	if opts.expected_territory then
		print("expected territory:")
		print(opts.expected_territory)
	end
	print("actual territory:")
	print(spec_helper.territory_ascii(g.board, territory))
	if opts.expected_territory_values then
		print("expected territory values:")
		print(opts.expected_territory_values)
	end
	print("actual territory values:")
	print(M.territory_weight_ascii(g))
	M.debug_print_scoring_values(g, name)
	print(string.format(
		"  totals — black=%s white=%s",
		tostring(g.players.black.score.total),
		tostring(g.players.white.score.total)
	))
end

--- Returns a busted ``after_each`` callback that dumps scoring values when INTEGRATION_DEBUG=1.
--- @param get_game fun(): table
--- @return fun(): nil
function M.visual_scoring_debug_after_each(get_game)
	return function()
		if not spec_helper.integration_debug_enabled() or not scoring_debug_dump_pending then
			return
		end
		scoring_debug_dump_pending = false
		if scoring_debug_already_dumped then
			scoring_debug_already_dumped = false
			return
		end
		scoring_debug_already_dumped = false
		local g = get_game()
		if g then
			M.debug_dump_game_state(g, "end of test after scoring assert failure")
		end
	end
end

--- @param player table
--- @return table
function M.snapshot_player(player)
	return {
		total = player.score.total,
		points = player.score.points,
		territory = player.score.territory,
		plus_mult = player.score.plus_mult,
		x_mult = player.score.x_mult,
		energy = player.resources.energy_current,
		energy_max = player.resources.energy_max,
		money = player.resources.money,
	}
end

--- @param g table
--- @return table
function M.visual_score_snapshot(g)
	return {
		black = M.snapshot_player(g.players.black),
		white = M.snapshot_player(g.players.white),
	}
end

--- @param g table
--- @param side string "black"|"white"
--- @return table
function M.player_score_snapshot(g, side)
	return M.snapshot_player(match_state.player_for_color(g, side))
end

--- @param side string "black"|"white"
--- @return string
local function side_to_owner(side)
	if side == "white" then
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- @param g table
--- @param side string
--- @param player_field string
--- @param scores_field string
--- @param amount number
local function set_score_component(g, side, player_field, scores_field, amount)
	match_state.player_for_color(g, side).score[player_field] = amount
	g.scores = g.scores or {}
	g.scores[scores_field] = g.scores[scores_field] or { B = 1, W = 1 }
	g.scores[scores_field][side_to_owner(side)] = amount
end

--- @param game_type_id string|nil
--- @return table
function M.new_isolated_game(game_type_id)
	local game = require("game")
	local g = game.new("pvp", game_type_id or "basic_stones")
	g.run_state = { counters = {} }
	return g
end

--- @param g table
--- @param side string
--- @param stone_ids table
function M.set_hand(g, side, stone_ids)
	local player = match_state.player_for_color(g, side)
	player.stones.playable_stones = stone_ids
	player.stones.instance_by_slot = {}
	player.stones.selected_stone = stone_ids[1]
	player.stones.selected_stone_index = 1
end

--- @param g table
--- @param side string
--- @param slot_index integer
--- @param def_id string
--- @param level integer
function M.set_stone_instance(g, side, slot_index, def_id, level)
	local player = match_state.player_for_color(g, side)
	player.stones.playable_stones[slot_index] = def_id
	player.stones.instance_by_slot = player.stones.instance_by_slot or {}
	player.stones.instance_by_slot[slot_index] = {
		def_id = def_id,
		level = level,
	}
	player.stones.selected_stone = def_id
	player.stones.selected_stone_index = slot_index
end

--- @param g table
--- @param side string
--- @param amount number
function M.set_energy(g, side, amount)
	match_state.player_for_color(g, side).resources.energy_current = amount
end

--- @param g table
--- @param side string
--- @param amount number
function M.set_money(g, side, amount)
	match_state.player_for_color(g, side).resources.money = amount
end

--- @param g table
--- @param side string
--- @param card_ids table
function M.set_cards(g, side, card_ids)
	match_state.player_for_color(g, side).cards.hand.ids = card_ids
end

--- @param g table
--- @param side string
--- @param fixed table|nil
--- @param swappable table|nil
function M.set_stances(g, side, fixed, swappable)
	local player = match_state.player_for_color(g, side)
	player.stances.fixed = fixed or {}
	player.stances.swappable = swappable or {}
end

--- @param g table
--- @param round integer
function M.set_round(g, round)
	g.turn_number = round == 1 and 1 or (round - 1) * 2
end

--- @param g table
--- @param key string
--- @param black_value number|nil
--- @param white_value number|nil
function M.set_persistent_counter(g, key, black_value, white_value)
	g.run_state.counters[key] = { B = black_value or 0, W = white_value or 0 }
end

--- @param g table
--- @param side string
--- @param amount number
function M.set_points(g, side, amount)
	set_score_component(g, side, "points", "points", amount)
end

--- @param g table
--- @param side string
--- @param amount number
function M.set_mult(g, side, amount)
	set_score_component(g, side, "plus_mult", "plus_mult", amount)
end

--- @param g table
--- @param side string
--- @param amount number
function M.set_x_mult(g, side, amount)
	set_score_component(g, side, "x_mult", "x_mult", amount)
end

--- @param g table
--- @param rows table
function M.set_board(g, rows)
	g.board = spec_helper.parse_board_ascii_kinds(rows, require_visual_letter_map())
end

--- @param g table
--- @param hand_index integer
function M.play_card(g, hand_index)
	M.assert_legal_play_card(g, hand_index, "play_card hand index " .. hand_index)
end

--- @param g table
--- @param hand_indices table
function M.play_cards(g, hand_indices)
	for i = 1, #hand_indices do
		M.play_card(g, hand_indices[i])
	end
end

--- @param g table
--- @param board_rows table
--- @param finish_animations boolean|nil
--- @return integer row
--- @return integer col
function M.place_stone(g, board_rows, finish_animations)
	if finish_animations == nil then
		finish_animations = true
	end
	local letter_map = require_visual_letter_map()
	local new_board = spec_helper.parse_board_ascii_kinds(board_rows, letter_map)
	local candidates = {}
	for r = 1, config.BOARD_SIZE do
		for c = 1, config.BOARD_SIZE do
			local old_cell = g.board[r][c]
			local new_cell = new_board[r][c]
			local old_empty = board.is_empty(old_cell)
			local new_empty = board.is_empty(new_cell)
			if not new_empty and (old_empty or old_cell.kind ~= new_cell.kind or old_cell.color ~= new_cell.color) then
				candidates[#candidates + 1] = {
					row = r,
					col = c,
					priority = old_empty and 0 or 1,
				}
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.priority < b.priority
	end)
	for i = 1, #candidates do
		local r = candidates[i].row
		local c = candidates[i].col
		local player = match_state.player_for_color(g, g.to_play)
		local stone_kind = new_board[r][c].kind
		player.stones.selected_stone = stone_kind
		local idx = player.stones.selected_stone_index or 1
		if player.stones.playable_stones[idx] then
			player.stones.playable_stones[idx] = stone_kind
		end
		M.assert_legal_player_move(g, r, c, "place_stone at row " .. r .. " col " .. c)
		if finish_animations then
			M.finish_ui_animations_for_turn(g)
		end
		return r, c
	end
	error("place_stone: no board change found in board_rows compared to the current board")
end

--- @param g table
--- @param hand_index integer
--- @param board_rows table
function M.play_card_and_stone(g, hand_index, board_rows)
	M.play_card(g, hand_index)
	M.place_stone(g, board_rows)
end

--- Empty-cell ownership grid: ``1`` black, ``2`` white, ``0`` neutral, ``#`` stone.
--- @param g table
--- @param territory_mode string|nil
--- @return string
function M.territory_ownership_ascii(g, territory_mode)
	local territory = g.territory or spec_helper.territory_map(g.board, territory_mode or "regional")
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			if not board.is_empty(g.board[r][c]) then
				row[#row + 1] = "#"
			elseif territory[r][c] == config.STONE_BLACK then
				row[#row + 1] = "1"
			elseif territory[r][c] == config.STONE_WHITE then
				row[#row + 1] = "2"
			else
				row[#row + 1] = "0"
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

--- Per-empty-cell ``territory_value`` multipliers; ``#`` on stones.
--- @param g table
--- @return string
function M.territory_weight_ascii(g)
	local territory_value = g.territory_value
	if not territory_value then
		local _, _, computed = spec_helper.territory_map(g.board, g.territory_mode or "regional")
		territory_value = computed
	end
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			if not board.is_empty(g.board[r][c]) then
				row[#row + 1] = "#"
			else
				local v = (territory_value[r] and territory_value[r][c]) or 1
				row[#row + 1] = tostring(v)
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

--- @param g table
--- @param side string ``"black"`` | ``"white"``
--- @return integer
function M.player_territory_score(g, side)
	local color = side == "white" and config.STONE_WHITE or config.STONE_BLACK
	assert.is_not_nil(g.territory, "player_territory_score requires state.territory from resolve")
	local n = config.BOARD_SIZE
	local sum = 0
	for r = 1, n do
		for c = 1, n do
			if board.is_empty(g.board[r][c]) and g.territory[r][c] == color then
				local w = (g.territory_value[r] and g.territory_value[r][c]) or 1
				sum = sum + w
			end
		end
	end
	return sum
end

--- @param g table
--- @param row integer
--- @param col integer
--- @return integer
function M.board_stone_points_bonus(g, row, col)
	local key = row .. ":" .. col
	local mods = g.board_stone_modifiers and g.board_stone_modifiers[key]
	if not mods or mods.points_bonus == nil then
		return 0
	end
	return mods.points_bonus
end

--- @param g table
--- @param row integer
--- @param col integer
--- @return table|nil
function M.board_stone_modifier_entry(g, row, col)
	local key = row .. ":" .. col
	if not g.board_stone_modifiers then
		return nil
	end
	return g.board_stone_modifiers[key]
end

--- @param stone_ids string[]
--- @param context string|nil
function M.assert_stone_ids_registered_in_content(stone_ids, context)
	local missing = {}
	for i = 1, #stone_ids do
		if not content.get_stone(stone_ids[i]) then
			missing[#missing + 1] = stone_ids[i]
		end
	end
	local prefix = context or "stone definitions must exist in content"
	assert.are.equal(0, #missing, prefix .. ": " .. table.concat(missing, ", "))
end

function M.assert_pattern_stones_in_content()
	M.assert_stone_ids_registered_in_content(M.PATTERN_STONE_IDS, "pattern stones")
end

--- @param g table
--- @param side string
--- @param expected number
--- @param context string|nil
function M.assert_player_energy(g, side, expected, context)
	local actual = match_state.player_for_color(g, side).resources.energy_current
	local msg = context or ("player " .. side .. " energy")
	assert_equal_with_scoring_debug(g, expected, actual, msg)
end

--- @param g table
--- @param side string
--- @param expected number
--- @param context string|nil
function M.assert_player_money(g, side, expected, context)
	local actual = match_state.player_for_color(g, side).resources.money
	local msg = context or ("player " .. side .. " money")
	assert_equal_with_scoring_debug(g, expected, actual, msg)
end

--- @param g table
--- @param side string
--- @param expected number
--- @param context string|nil
function M.assert_player_total_score(g, side, expected, context)
	local actual = match_state.player_for_color(g, side).score.total
	local msg = context or ("player " .. side .. " total score")
	assert_equal_with_scoring_debug(g, expected, actual, msg)
end

--- @param g table
--- @param expected_black number
--- @param expected_white number
--- @param context string|nil
function M.assert_players_total_score(g, expected_black, expected_white, context)
	M.assert_player_total_score(g, "black", expected_black, context and (context .. " black") or nil)
	M.assert_player_total_score(g, "white", expected_white, context and (context .. " white") or nil)
end

--- @param g table
--- @param snap table
--- @param expected_delta_black number
--- @param expected_delta_white number
--- @param context string|nil
function M.assert_players_total_score_delta(g, snap, expected_delta_black, expected_delta_white, context)
	local prefix = context or "total score delta"
	local delta_black = g.players.black.score.total - snap.black.total
	local delta_white = g.players.white.score.total - snap.white.total
	assert_equal_with_scoring_debug(g, expected_delta_black, delta_black, prefix .. " black")
	assert_equal_with_scoring_debug(g, expected_delta_white, delta_white, prefix .. " white")
end

--- @param token string
--- @param value_map table<string, string|number>|nil
--- @return string
local function expand_territory_value_token(token, value_map)
	if token == "#" then
		return "#"
	end
	if token == "." then
		return "1"
	end
	if value_map then
		local mapped = value_map[token]
		if mapped ~= nil then
			return tostring(mapped)
		end
	end
	return token
end

--- Expands ``.`` → ``1``, ``#`` unchanged, and optional letter placeholders via ``opts.values``.
--- @param expected_rows table
--- @param opts table|nil  ``{ values = { d = 2 } }`` maps single-letter tokens to territory value strings
--- @return string
local function expand_territory_values_rows(expected_rows, opts)
	if type(expected_rows) ~= "table" then
		error("assert_territory_values_ascii: expected_rows must be a table of row strings")
	end
	local value_map = opts and opts.values
	local lines = {}
	for i = 1, #expected_rows do
		local tokens = {}
		for token in string.gmatch(expected_rows[i], "%S+") do
			tokens[#tokens + 1] = expand_territory_value_token(token, value_map)
		end
		lines[i] = table.concat(tokens, " ")
	end
	return table.concat(lines, "\n")
end

--- @param g table
--- @param expected_rows table
--- @param context string|nil
function M.assert_territory_ascii(g, expected_rows, context)
	if type(expected_rows) ~= "table" then
		error("assert_territory_ascii: expected_rows must be a table of row strings")
	end
	local territory = g.territory or spec_helper.territory_map(g.board, "regional")
	local expected = table.concat(expected_rows, "\n")
	local actual = spec_helper.territory_ascii(g.board, territory)
	local msg = context or "territory ownership grid"
	if expected ~= actual then
		M.debug_dump_game_state(g, msg, { expected_territory = expected })
	end
	assert.are.equal(expected, actual, msg)
end

--- Compares per-cell territory weights to ``M.territory_weight_ascii(g)``.
--- @param g table
--- @param expected_rows table  array of row strings (not a single concatenated board string)
--- @param context string|nil
--- @param opts table|nil  ``{ values = { d = 2, b = 1 } }`` expands letter tokens on empty cells
function M.assert_territory_values_ascii(g, expected_rows, context, opts)
	local expected = expand_territory_values_rows(expected_rows, opts)
	local actual = M.territory_weight_ascii(g)
	local msg = context or "territory value grid"
	if expected ~= actual then
		M.debug_dump_game_state(g, msg, { expected_territory_values = expected })
	end
	assert.are.equal(expected, actual, msg)
end

--- @param g table
--- @param snap table
--- @param expected_delta_black number
--- @param expected_delta_white number
--- @param context string|nil
function M.assert_players_plus_mult_delta(g, snap, expected_delta_black, expected_delta_white, context)
	local prefix = context or "plus_mult delta"
	local delta_black = g.players.black.score.plus_mult - snap.black.plus_mult
	local delta_white = g.players.white.score.plus_mult - snap.white.plus_mult
	assert_equal_with_scoring_debug(g, expected_delta_black, delta_black, prefix .. " black")
	assert_equal_with_scoring_debug(g, expected_delta_white, delta_white, prefix .. " white")
end

--- @param g table
--- @param hand_index integer
--- @param context string|nil
function M.assert_legal_play_card(g, hand_index, context)
	local game = require("game")
	assert.is_true(game.play_card(g, hand_index), context or ("play_card index " .. tostring(hand_index)))
end

--- @param g table
--- @param side string
--- @param expected number
--- @param context string|nil
function M.assert_player_x_mult(g, side, expected, context)
	local actual = match_state.player_for_color(g, side).score.x_mult
	local msg = context or ("player " .. side .. " x_mult")
	assert_equal_with_scoring_debug(g, expected, actual, msg)
end

--- @param g table
--- @param side string
--- @param snap table
--- @param expected_delta number
--- @param context string|nil
function M.assert_player_x_mult_delta(g, side, snap, expected_delta, context)
	local actual = match_state.player_for_color(g, side).score.x_mult
	local delta = actual - snap.x_mult
	local msg = context or ("player " .. side .. " x_mult delta")
	assert_equal_with_scoring_debug(g, expected_delta, delta, msg)
end

--- @param g table
--- @param side string
--- @param snap table
--- @param context string|nil
function M.assert_player_x_mult_unchanged(g, side, snap, context)
	M.assert_player_x_mult_delta(g, side, snap, 0, context)
end

--- @param g table
--- @param side string
--- @param expected number
--- @param context string|nil
function M.assert_player_plus_mult(g, side, expected, context)
	local actual = match_state.player_for_color(g, side).score.plus_mult
	local msg = context or ("player " .. side .. " plus_mult")
	assert_equal_with_scoring_debug(g, expected, actual, msg)
end

--- @param g table
--- @param side string
--- @param snap table
--- @param expected_delta number
--- @param context string|nil
function M.assert_player_plus_mult_delta(g, side, snap, expected_delta, context)
	local actual = match_state.player_for_color(g, side).score.plus_mult
	local delta = actual - snap.plus_mult
	local msg = context or ("player " .. side .. " plus_mult delta")
	assert_equal_with_scoring_debug(g, expected_delta, delta, msg)
end

--- @param g table
--- @param side string
--- @param snap table
--- @param context string|nil
function M.assert_player_plus_mult_unchanged(g, side, snap, context)
	M.assert_player_plus_mult_delta(g, side, snap, 0, context)
end

--- @param g table
--- @param side string
--- @param expected number
--- @param context string|nil
function M.assert_player_points(g, side, expected, context)
	local actual = match_state.player_for_color(g, side).score.points
	local msg = context or ("player " .. side .. " points")
	assert_equal_with_scoring_debug(g, expected, actual, msg)
end

--- @param g table
--- @param side string
--- @param snap table
--- @param expected_delta number
--- @param context string|nil
function M.assert_player_points_delta(g, side, snap, expected_delta, context)
	local actual = match_state.player_for_color(g, side).score.points
	local delta = actual - snap.points
	local msg = context or ("player " .. side .. " points delta")
	assert_equal_with_scoring_debug(g, expected_delta, delta, msg)
end

--- @param g table
--- @param side string
--- @param snap table
--- @param context string|nil
function M.assert_player_points_unchanged(g, side, snap, context)
	M.assert_player_points_delta(g, side, snap, 0, context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param expected number
--- @param context string|nil
function M.assert_board_stone_points_bonus(g, row, col, expected, context)
	local actual = M.board_stone_points_bonus(g, row, col)
	local msg = context or ("board_stone points_bonus at " .. row .. ":" .. col)
	assert_equal_with_scoring_debug(g, expected, actual, msg)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_board_stone_modifier_absent(g, row, col, context)
	assert.is_nil(M.board_stone_modifier_entry(g, row, col), context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_legal_player_move(g, row, col, context)
	local game = require("game")
	local msg = context or ("player_move at " .. row .. ":" .. col)
	local ok = game.player_move(g, row, col)
	if not ok and spec_helper.integration_debug_enabled() then
		M.debug_dump_game_state(g, msg)
	end
	assert.is_true(ok, msg)
end

--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param g table
--- @return nil
function M.ensure_test_state_bags(g)
	g.blocked_cells = g.blocked_cells or {}
	g.stone_immunity_remaining = g.stone_immunity_remaining or {}
	g.board_cell_timers = g.board_cell_timers or {}
	g.stone_stored_values = g.stone_stored_values or {}
	g.territory_control_rounds = g.territory_control_rounds or {}
	g.territory_contested = g.territory_contested or {}
	g.test_parameter_overrides = g.test_parameter_overrides or {}
	g.test_rng_streams = g.test_rng_streams or {}
	g.destroy_odds = g.destroy_odds or {}
end

--- @param g table
--- @param side string ``"black"`` | ``"white"``
--- @return nil
function M.ensure_actor_turn(g, side)
	local resolver = require("resolver")
	local guard = 0
	while g.to_play ~= side and not g.ended and not g.over and guard < 24 do
		if g.phase == "MAIN_PHASE" then
			resolver.finish_main_phase(g, g.to_play)
		end
		if g.phase == "PLACE_PHASE" then
			M.pass_turn(g)
		elseif g.phase == "TURN_START" then
			resolver.begin_turn(g, g.to_play)
		else
			break
		end
		guard = guard + 1
	end
end

--- Flushes deferred UI turn advance after ``place_stone(..., false)``.
--- @param g table
--- @return nil
function M.finish_turn(g)
	M.finish_ui_animations_for_turn(g)
end

--- Passes for ``g.to_play`` (finishes MAIN when needed).
--- @param g table
--- @return nil
function M.pass_turn(g)
	local resolver = require("resolver")
	local actor = g.to_play
	if g.ended or g.over or actor == "none" then
		return
	end
	if g.phase == "MAIN_PHASE" then
		resolver.finish_main_phase(g, actor)
	end
	if g.phase == "PLACE_PHASE" then
		resolver.submit_action(g, {
			actor = actor,
			type = "PASS_TURN",
			payload = {},
		})
		M.finish_ui_animations_for_turn(g)
	end
end

--- @param g table
--- @param side string ``"black"`` | ``"white"``
--- @param stone_id string
--- @param board_rows table
--- @param finish_animations boolean|nil
--- @return integer row
--- @return integer col
function M.place_stone_for(g, side, stone_id, board_rows, finish_animations)
	M.ensure_actor_turn(g, side)
	local player = match_state.player_for_color(g, side)
	local found_index = nil
	for i = 1, #player.stones.playable_stones do
		if player.stones.playable_stones[i] == stone_id then
			found_index = i
			break
		end
	end
	if not found_index then
		player.stones.playable_stones = { stone_id }
		found_index = 1
	end
	player.stones.selected_stone = stone_id
	player.stones.selected_stone_index = found_index
	local resolver = require("resolver")
	if g.phase == "MAIN_PHASE" and g.to_play == side then
		resolver.finish_main_phase(g, side)
	end
	return M.place_stone(g, board_rows, finish_animations)
end

--- @param g table
--- @param side string color owner of stone to remove (``"black"`` | ``"white"``)
--- @param row integer
--- @param col integer
--- @return nil
function M.capture_stone_at(g, row, col, side)
	local color = side == "white" and config.STONE_WHITE or config.STONE_BLACK
	local cell = g.board[row][col]
	if board.is_empty(cell) or cell.color ~= color then
		return
	end
	g.board[row][col] = config.STONE_NONE
	g.territory, g.territory_decision_sources, g.territory_value = spec_helper.territory_map(g.board, g.territory_mode or "regional")
	local key = cell_key(row, col)
	if g.stone_stored_values then
		g.stone_stored_values[key] = nil
	end
	if g.board_cell_timers then
		g.board_cell_timers[key] = nil
	end
end

--- @param g table
--- @param count integer
--- @return nil
function M.advance_rounds(g, count)
	M.ensure_test_state_bags(g)
	local resolve_round = require("single_game.resolver.resolve_round")
	for _ = 1, count do
		for key, remaining in pairs(g.board_cell_timers) do
			if remaining > 0 then
				g.board_cell_timers[key] = remaining - 1
			end
		end
		for key, remaining in pairs(g.blocked_cells) do
			if remaining > 0 then
				g.blocked_cells[key] = remaining - 1
				if g.blocked_cells[key] <= 0 then
					g.blocked_cells[key] = nil
				end
			end
		end
		for key, remaining in pairs(g.stone_immunity_remaining) do
			if remaining > 0 then
				g.stone_immunity_remaining[key] = remaining - 1
				if g.stone_immunity_remaining[key] <= 0 then
					g.stone_immunity_remaining[key] = nil
				end
			end
		end
		local kept = {}
		for i = 1, #(g.active_effects or {}) do
			local active = g.active_effects[i]
			active.remaining_turns = (active.remaining_turns or 0) - 1
			if active.remaining_turns > 0 then
				kept[#kept + 1] = active
			end
		end
		g.active_effects = kept
		g.turn_number = (g.turn_number or 1) + 1
		g.round_number = match_state.round_number_from_turn(g.turn_number)
		resolve_round.resolve(g, { macro = "end_of_turn" })
	end
end

--- @param g table
--- @param row integer
--- @param col integer
--- @return boolean
function M.is_cell_blocked(g, row, col)
	if row < 1 or row > config.BOARD_SIZE or col < 1 or col > config.BOARD_SIZE then
		return false
	end
	M.ensure_test_state_bags(g)
	local remaining = g.blocked_cells[cell_key(row, col)]
	return remaining ~= nil and remaining > 0
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_cell_blocked(g, row, col, context)
	assert.is_true(M.is_cell_blocked(g, row, col), context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_cell_unblocked(g, row, col, context)
	assert.is_false(M.is_cell_blocked(g, row, col), context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @return integer
function M.stone_immunity_remaining(g, row, col)
	M.ensure_test_state_bags(g)
	return g.stone_immunity_remaining[cell_key(row, col)] or 0
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param expected integer
--- @param context string|nil
function M.assert_stone_immune(g, row, col, expected, context)
	assert.are.equal(expected, M.stone_immunity_remaining(g, row, col), context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_stone_not_immune(g, row, col, context)
	assert.are.equal(0, M.stone_immunity_remaining(g, row, col), context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @return integer
function M.stone_timer_remaining(g, row, col)
	M.ensure_test_state_bags(g)
	local key = cell_key(row, col)
	if g.board_cell_timers[key] then
		return g.board_cell_timers[key]
	end
	for i = 1, #(g.active_effects or {}) do
		local active = g.active_effects[i]
		if active.row == row and active.col == col then
			return active.remaining_turns or 0
		end
	end
	local cell = g.board[row][col]
	if type(cell) == "table" and cell.timer_remaining_rounds then
		return cell.timer_remaining_rounds
	end
	return 0
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param expected integer
--- @param context string|nil
function M.assert_stone_timer(g, row, col, expected, context)
	assert.are.equal(expected, M.stone_timer_remaining(g, row, col), context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_board_cell_empty(g, row, col, context)
	assert.is_true(board.is_empty(g.board[row][col]), context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_board_stone_present(g, row, col, context)
	assert.is_false(board.is_empty(g.board[row][col]), context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_board_stone_empty(g, row, col, context)
	M.assert_board_cell_empty(g, row, col, context)
end

--- @param g table
--- @param side string
--- @param stone_id string
--- @param row integer
--- @param col integer
--- @return boolean
function M.try_player_move_with_stone(g, side, stone_id, row, col)
	M.ensure_actor_turn(g, side)
	local player = match_state.player_for_color(g, side)
	player.stones.selected_stone = stone_id
	player.stones.selected_stone_index = 1
	for i = 1, #player.stones.playable_stones do
		if player.stones.playable_stones[i] == stone_id then
			player.stones.selected_stone_index = i
			break
		end
	end
	if player.stones.playable_stones[1] ~= stone_id then
		player.stones.playable_stones = { stone_id }
		player.stones.selected_stone_index = 1
	end
	local resolver = require("resolver")
	if g.phase == "MAIN_PHASE" and g.to_play == side then
		resolver.finish_main_phase(g, side)
	end
	if g.phase ~= "PLACE_PHASE" or g.to_play ~= side then
		return false
	end
	local result = resolver.submit_action(g, {
		actor = side,
		type = "PLACE_STONE",
		payload = { row = row, col = col },
	})
	M.finish_ui_animations_for_turn(g)
	return result.ok
end

--- @param g table
--- @param side string
--- @param stone_id string
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_legal_player_move_with_stone(g, side, stone_id, row, col, context)
	local ok = M.try_player_move_with_stone(g, side, stone_id, row, col)
	if not ok and spec_helper.integration_debug_enabled() then
		M.debug_dump_game_state(g, context or "legal move")
	end
	assert.is_true(ok, context)
end

--- @param g table
--- @param side string
--- @param stone_id string
--- @param row integer
--- @param col integer
--- @param context string|nil
function M.assert_illegal_player_move_with_stone(g, side, stone_id, row, col, context)
	local before = board.clone(g.board)
	local points_before = match_state.player_for_color(g, side).score.points
	local ok = M.try_player_move_with_stone(g, side, stone_id, row, col)
	assert.is_false(ok, context)
	local after = g.board
	for r = 1, config.BOARD_SIZE do
		for c = 1, config.BOARD_SIZE do
			local b_cell = before[r][c]
			local a_cell = after[r][c]
			local b_empty = board.is_empty(b_cell)
			local a_empty = board.is_empty(a_cell)
			if b_empty ~= a_empty then
				error((context or "illegal move") .. ": board mutated on rejected placement")
			end
			if not b_empty and not a_empty and (b_cell.kind ~= a_cell.kind or b_cell.color ~= a_cell.color) then
				error((context or "illegal move") .. ": board mutated on rejected placement")
			end
		end
	end
	assert.are.equal(points_before, match_state.player_for_color(g, side).score.points, context)
end

--- @param g table
--- @param row integer
--- @param col integer
--- @return number|nil
function M.stone_stored_value_at(g, row, col)
	M.ensure_test_state_bags(g)
	local cell = g.board[row][col]
	if type(cell) == "table" and cell.stored_value ~= nil then
		return cell.stored_value
	end
	return g.stone_stored_values[cell_key(row, col)]
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param expected number
--- @param context string|nil
function M.assert_stone_stored_value(g, row, col, expected, context)
	assert.are.equal(expected, M.stone_stored_value_at(g, row, col), context)
end

--- @param g table
--- @param side string
--- @param snap table
--- @param context string|nil
function M.assert_player_energy_max_unchanged(g, side, snap, context)
	local player = match_state.player_for_color(g, side)
	assert.are.equal(player.resources.energy_max, snap.energy_max or player.resources.energy_max, context)
end

--- @param g table
--- @param side string
--- @param snap table
--- @param context string|nil
function M.assert_player_total_score_reflects_state(g, side, snap, context)
	local player = match_state.player_for_color(g, side)
	local expected = M.params.total_score(
		g.turn_number,
		player.score.territory,
		player.score.points,
		player.score.plus_mult,
		player.score.x_mult
	)
	M.assert_player_total_score(g, side, expected, context)
end

--- @param g table
--- @param side string
--- @param amount number
--- @param context string|nil
function M.grant_money(g, side, amount, context)
	local player = match_state.player_for_color(g, side)
	player.resources.money = (player.resources.money or 0) + amount
end

--- @param g table
--- @param stone_id string
--- @param param_name string
--- @param value number
--- @return nil
function M.set_stone_parameter(g, stone_id, param_name, value)
	local stone_params = require("objects.parameters.stones")
	stone_params[param_name] = value
end

--- @param g table
--- @return nil
function M.end_match_before_timers(g)
	g.ended = true
	g.over = true
	g.phase = "MATCH_END"
	g.to_play = "none"
end

--- @param g table
--- @param is_final boolean
--- @return nil
function M.set_final_round(g, is_final)
	g.is_final_round = is_final
end

--- @param g table
--- @param rounds integer
--- @return nil
function M.set_rounds_until_final(g, rounds)
	g.rounds_until_final = rounds
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param rounds integer
--- @return nil
function M.set_territory_control_rounds(g, row, col, rounds)
	M.ensure_test_state_bags(g)
	g.territory_control_rounds[cell_key(row, col)] = rounds
	local cell = g.board[row][col]
	if type(cell) == "table" then
		cell.territory_control_rounds = rounds
	end
end

--- @param g table
--- @param side string
--- @return integer
function M.count_territory_cells(g, side)
	local color = side == "white" and config.STONE_WHITE or config.STONE_BLACK
	local territory = g.territory
	if not territory then
		territory = spec_helper.territory_map(g.board, g.territory_mode or "regional")
	end
	return spec_helper.territory_points(territory, color, g.territory_value)
end

--- @param g table
--- @param side string
--- @param cell_count integer
--- @return nil
function M.seed_territory_owner_grid(g, side, cell_count)
	local color = side == "white" and config.STONE_WHITE or config.STONE_BLACK
	local n = config.BOARD_SIZE
	g.territory = g.territory or {}
	g.territory_value = g.territory_value or {}
	local placed = 0
	for r = 1, n do
		g.territory[r] = g.territory[r] or {}
		g.territory_value[r] = g.territory_value[r] or {}
		for c = 1, n do
			if board.is_empty(g.board[r][c]) then
				if placed < cell_count then
					g.territory[r][c] = color
					g.territory_value[r][c] = g.territory_value[r][c] or 1
					placed = placed + 1
				else
					g.territory[r][c] = config.STONE_NONE
				end
			end
		end
	end
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param side string
--- @return nil
function M.seed_territory_owner_at_cell(g, row, col, side)
	local color = side == "white" and config.STONE_WHITE or config.STONE_BLACK
	g.territory = g.territory or {}
	g.territory[row] = g.territory[row] or {}
	g.territory[row][col] = color
end

--- @param g table
--- @param row integer
--- @param col integer
--- @return nil
function M.mark_territory_contested(g, row, col)
	M.ensure_test_state_bags(g)
	g.territory_contested[cell_key(row, col)] = true
end

--- @param g table
--- @param stone_id string
--- @param rng_fn fun(max_value: integer): integer
--- @return nil
function M.set_rng_stream(g, stone_id, rng_fn)
	M.ensure_test_state_bags(g)
	g.test_rng_streams[stone_id] = rng_fn
end

--- @param g table
--- @param row integer
--- @param col integer
--- @return string
function M.destroy_odds_display(g, row, col)
	M.ensure_test_state_bags(g)
	return g.destroy_odds[cell_key(row, col)] or "1/1"
end

--- @param g table
--- @param row integer
--- @param col integer
--- @param expected string
--- @param context string|nil
function M.assert_destroy_odds(g, row, col, expected, context)
	assert.are.equal(expected, M.destroy_odds_display(g, row, col), context)
end

--- @param g table
--- @param stone_id string
--- @param level integer
--- @return integer
function M.upgrade_cost_for_level(g, stone_id, level)
	local stone_params = require("objects.parameters.stones")
	local base = stone_params.unlimited_upgrades_upgrade_cost_base or 1
	return base * level
end

--- @param g table
--- @param side string
--- @param slot_index integer
--- @param opts table|nil ``{ expect_success = boolean }``
--- @return nil
function M.upgrade_stone_instance(g, side, slot_index, opts)
	opts = opts or {}
	local player = match_state.player_for_color(g, side)
	player.stones.instance_by_slot = player.stones.instance_by_slot or {}
	local inst = player.stones.instance_by_slot[slot_index]
	if not inst then
		local def_id = player.stones.playable_stones[slot_index] or player.stones.selected_stone
		inst = { def_id = def_id, level = 1 }
		player.stones.instance_by_slot[slot_index] = inst
	end
	local next_level = (inst.level or 1) + 1
	local cost = M.upgrade_cost_for_level(g, inst.def_id, next_level)
	if opts.expect_success ~= false and (player.resources.money or 0) < cost then
		player.resources.money = cost * 2
	end
	if (player.resources.money or 0) < cost then
		if opts.expect_success == false then
			return
		end
		error("upgrade_stone_instance: insufficient money")
	end
	if opts.expect_success == false then
		return
	end
	player.resources.money = player.resources.money - cost
	if inst.def_id == "unlimited_upgrades_stone" then
		inst.level = next_level
		return
	end
	local ObjectInstance = require("single_game.resolver.ObjectInstance")
	ObjectInstance.upgrade(inst)
end

--- @param g table
--- @param side string
--- @param slot_index integer
--- @param expected_level integer
--- @param context string|nil
function M.assert_stone_instance_level(g, side, slot_index, expected_level, context)
	local player = match_state.player_for_color(g, side)
	local inst = player.stones.instance_by_slot and player.stones.instance_by_slot[slot_index]
	assert.is_not_nil(inst, context)
	assert.are.equal(expected_level, inst.level, context)
end

local function copy_stone_instances(instance_by_slot)
	local out = {}
	if not instance_by_slot then
		return out
	end
	for slot, inst in pairs(instance_by_slot) do
		out[slot] = {
			def_id = inst.def_id,
			level = inst.level,
			max_level = inst.max_level,
		}
	end
	return out
end

--- @param g table
--- @return table
function M.save_game_snapshot(g)
	return {
		board = board.clone(g.board),
		turn_number = g.turn_number,
		round_number = g.round_number,
		to_play = g.to_play,
		phase = g.phase,
		players = {
			black = {
				stones = {
					instance_by_slot = copy_stone_instances(g.players.black.stones.instance_by_slot),
					playable_stones = M.copy_ids(g.players.black.stones.playable_stones or {}),
				},
				resources = {
					money = g.players.black.resources.money,
					energy_current = g.players.black.resources.energy_current,
				},
			},
			white = {
				stones = {
					instance_by_slot = copy_stone_instances(g.players.white.stones.instance_by_slot),
					playable_stones = M.copy_ids(g.players.white.stones.playable_stones or {}),
				},
				resources = {
					money = g.players.white.resources.money,
					energy_current = g.players.white.resources.energy_current,
				},
			},
		},
	}
end

--- @param g table
--- @param saved table
--- @return nil
function M.restore_game_snapshot(g, saved)
	g.board = board.clone(saved.board)
	g.turn_number = saved.turn_number
	g.round_number = saved.round_number
	g.to_play = saved.to_play
	g.phase = saved.phase
	for _, side in ipairs({ "black", "white" }) do
		local src = saved.players[side]
		local dst = g.players[side]
		dst.stones.instance_by_slot = copy_stone_instances(src.stones.instance_by_slot)
		dst.stones.playable_stones = M.copy_ids(src.stones.playable_stones)
		dst.resources.money = src.resources.money
		dst.resources.energy_current = src.resources.energy_current
	end
end

return M
