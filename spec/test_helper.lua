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

local debug_stone_to_letter = nil
local scoring_debug_dump_pending = false
local scoring_debug_already_dumped = false

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
	print(M.territory_value_ascii(g))
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

--- Sets baseline score points on both ``players.*.score`` and ``state.scores.points`` before resolve.
--- @param g table
--- @param side string "black"|"white"
--- @param amount number
function M.set_points(g, side, amount)
	match_state.player_for_color(g, side).score.points = amount
	g.scores = g.scores or {}
	g.scores.points = g.scores.points or { B = 1, W = 1 }
	g.scores.points[side_to_owner(side)] = amount
end

--- @param g table
--- @param territory_mode string|nil
--- @return string
function M.territory_value_ascii(g, territory_mode)
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

--- @param g table
--- @param expected_rows table
--- @param context string|nil
function M.assert_territory_ascii(g, expected_rows, context)
	local territory = g.territory or spec_helper.territory_map(g.board, "regional")
	local expected = table.concat(expected_rows, "\n")
	local actual = spec_helper.territory_ascii(g.board, territory)
	local msg = context or "territory ownership grid"
	if expected ~= actual then
		M.debug_dump_game_state(g, msg, { expected_territory = expected })
	end
	assert.are.equal(expected, actual, msg)
end

--- @param g table
--- @param expected_rows table
--- @param context string|nil
function M.assert_territory_values_ascii(g, expected_rows, context)
	local expected = table.concat(expected_rows, "\n")
	local actual = M.territory_value_ascii(g)
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

return M
