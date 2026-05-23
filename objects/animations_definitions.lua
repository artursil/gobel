--- Registered animation builder implementations (``function(state, args)``). Consumed only by ``objects.animations``
--- factory wiring; gameplay uses ``add_animation(name)(state, args)``.
--- @module objects.animations_definitions

local animations_constants = require("objects.animations_constants")
local animations_helper = require("objects.animations_helper")
local shape_patterns = require("game.patterns.shape_patterns")

local STEEL_SYNC_DEF_ID = "stance_gluttony"

local M = {}

--- @param state table
--- @param owner string
--- @return table
local function next_sequence_id(state)
	state.ui_animation_events = state.ui_animation_events or {}
	state.ui_animation_seq_counter = (state.ui_animation_seq_counter or 0) + 1
	return "pattern:" .. tostring(state.ui_animation_seq_counter)
end

--- @param ev table[]
--- @param seq_id string
--- @param owner string
--- @param cells table[]
--- @param step_ms integer
--- @return nil
local function append_bounce_steps(ev, seq_id, owner, cells, step_ms)
	for i = 1, #cells do
		local cell = cells[i]
		ev[#ev + 1] = {
			type = "board_stone_bounce",
			sequence_id = seq_id,
			start_delay_ms = 0,
			duration_ms = step_ms,
			owner = owner,
			row = cell[1],
			col = cell[2],
		}
	end
end

--- @param ev table[]
--- @param seq_id string
--- @param owner string
--- @param markers table[] { row, col, text }
--- @return nil
local function append_marker_floats(ev, seq_id, owner, markers)
	for i = 1, #markers do
		local m = markers[i]
		ev[#ev + 1] = {
			type = "board_stone_float_text",
			sequence_id = seq_id,
			start_delay_ms = 0,
			duration_ms = animations_constants.BOARD_STONE_FLOAT_MS,
			owner = owner,
			row = m.row,
			col = m.col,
			text = m.text,
		}
	end
end

--- @param board_after table
--- @param cells table[]
--- @param kind string
--- @return table[]
local function marker_cells_for_kind(board_after, cells, kind)
	local out = {}
	for i = 1, #cells do
		local r, c = cells[i][1], cells[i][2]
		local cell = board_after[r][c]
		if cell and cell.kind == kind then
			out[#out + 1] = { row = r, col = c }
		end
	end
	return out
end

--- X completed: bounce every cell in the pattern, then per-``x_stone`` ``×2`` (one tier step each).
--- **Args**: ``owner``, ``cells``, ``board_after``.
--- @param state table
--- @param args table
--- @return nil
local function enqueue_pattern_x_celebrate(state, args)
	local owner = args.owner
	local cells = args.cells
	local board_after = args.board_after
	if not owner or not cells or #cells == 0 or not board_after then
		return
	end
	local seq_id = next_sequence_id(state)
	local ev = state.ui_animation_events
	local step_ms = animations_helper.board_stone_bounce_step_duration_ms(#cells)
	append_bounce_steps(ev, seq_id, owner, cells, step_ms)
	local x_cells = marker_cells_for_kind(board_after, cells, "x_stone")
	local per_stone = shape_patterns.pattern_scoring.x_mult_per_tier
	local label = string.format("×%d", per_stone)
	local markers = {}
	for i = 1, #x_cells do
		markers[i] = { row = x_cells[i].row, col = x_cells[i].col, text = label }
	end
	append_marker_floats(ev, seq_id, owner, markers)
end

--- + completed: bounce every cell, then ``+N`` over each ``plus_stone`` (``N`` = ``plus_mult_per_tier``).
--- **Args**: ``owner``, ``cells``, ``board_after``.
--- @param state table
--- @param args table
--- @return nil
local function enqueue_pattern_plus_celebrate(state, args)
	local owner = args.owner
	local cells = args.cells
	local board_after = args.board_after
	if not owner or not cells or #cells == 0 or not board_after then
		return
	end
	local seq_id = next_sequence_id(state)
	local ev = state.ui_animation_events
	local step_ms = animations_helper.board_stone_bounce_step_duration_ms(#cells)
	append_bounce_steps(ev, seq_id, owner, cells, step_ms)
	local p_cells = marker_cells_for_kind(board_after, cells, "plus_stone")
	local per_stone = shape_patterns.pattern_scoring.plus_mult_per_tier
	local plus_label = string.format("+%d", per_stone)
	local markers = {}
	for i = 1, #p_cells do
		markers[i] = { row = p_cells[i].row, col = p_cells[i].col, text = plus_label }
	end
	append_marker_floats(ev, seq_id, owner, markers)
end

--- Wall placed with group size ≥ 5: bounce connected group, then one ``+5`` float per 5 stones.
--- **Args**: ``owner``, ``cells``, ``anchor_row``, ``anchor_col``, ``bonus`` (total points, multiple of 5).
--- @param state table
--- @param args table
--- @return nil
local function enqueue_wall_stone_bounce(state, args)
	local owner = args.owner
	local cells = args.cells
	local anchor_row = args.anchor_row
	local anchor_col = args.anchor_col
	local bonus = args.bonus
	if not owner or not cells or #cells < 5 or not anchor_row or not anchor_col or type(bonus) ~= "number" or bonus <= 0 then
		return
	end
	local seq_id = next_sequence_id(state)
	local ev = state.ui_animation_events
	local step_ms = animations_helper.board_stone_bounce_step_duration_ms(#cells)
	append_bounce_steps(ev, seq_id, owner, cells, step_ms)
	local blocks = math.floor(bonus / shape_patterns.pattern_scoring.wall_points_per_block)
	local wall_label = string.format("+%d", shape_patterns.pattern_scoring.wall_points_per_block)
	local markers = {}
	for _ = 1, blocks do
		markers[#markers + 1] = { row = anchor_row, col = anchor_col, text = wall_label }
	end
	append_marker_floats(ev, seq_id, owner, markers)
end

--- Steel sync: stance shake + sequential ``hand_card_float_text`` per steel card in hand.
--- @param state table
--- @param args table
--- @return nil
function M.steel_sync_mult(state, args)
	local owner = args.owner
	local steel_hand_indices = args.steel_hand_indices
	local factor = args.factor
	local x_mult_steps = args.x_mult_steps
	local r = state.resolution
	if not r or r.source_def_id ~= STEEL_SYNC_DEF_ID or r.source_object_type ~= "stance" then
		return
	end
	if not steel_hand_indices or #steel_hand_indices == 0 or type(factor) ~= "number" then
		return
	end
	if not x_mult_steps or #x_mult_steps ~= #steel_hand_indices then
		return
	end
	state.ui_animation_events = state.ui_animation_events or {}
	state.ui_animation_seq_counter = (state.ui_animation_seq_counter or 0) + 1
	local seq_id = "steel_sync:" .. tostring(state.ui_animation_seq_counter)
	local ev = state.ui_animation_events
	local stance_slot = animations_helper.get_stance_index(state, owner)
	local inst = r.source_instance_id
	local label = string.format("×%.1f", factor)
	local float_step_ms = animations_helper.steel_hand_float_step_duration_ms(#steel_hand_indices)
	local n = #steel_hand_indices
	ev[#ev + 1] = {
		type = "stance_shake",
		sequence_id = seq_id,
		start_delay_ms = 0,
		owner = owner,
		stance_def_id = STEEL_SYNC_DEF_ID,
		stance_slot_index = stance_slot,
		stance_instance_id = inst,
	}
	for i = 1, n do
		ev[#ev + 1] = {
			type = "hand_card_float_text",
			sequence_id = seq_id,
			start_delay_ms = 0,
			duration_ms = float_step_ms,
			owner = owner,
			hand_index = steel_hand_indices[i],
			text = label,
			presented_x_mult = x_mult_steps[i],
		}
	end
end

--- @param state table
--- @param args table
--- @return nil
function M.pattern_x_celebrate(state, args)
	enqueue_pattern_x_celebrate(state, args)
end

--- @param state table
--- @param args table
--- @return nil
function M.pattern_plus_celebrate(state, args)
	enqueue_pattern_plus_celebrate(state, args)
end

--- @param state table
--- @param args table
--- @return nil
function M.wall_stone_bounce(state, args)
	enqueue_wall_stone_bounce(state, args)
end

return M
