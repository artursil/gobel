--- Shared immediate-placement compile path and resolved-type → round-def mapping.
--- Used by resolver placement compile and AI placement scoring (read-only mirror).
--- @module objects.placement_effect_registry

local board = require("board")
local config = require("config")
local content = require("content")
local effects_helpers = require("objects.effects_helpers")
local territory_control_rounds = require("single_game.resolver.territory_control_rounds")

local M = {}

--- Effect names compiled for on-place scoring before ``resolve_round``.
M.IMMEDIATE_PLACEMENT_EFFECT_NAMES = {
	add_points = true,
	add_mult = true,
	add_energy = true,
	add_money = true,
	mult_control_streak = true,
	kamikaze_sacrifice = true,
	money_field_enclosure_payout = true,
	self_destruct_timed = true,
}

--- Placement commit hooks that run at ``BOARD_APPLY`` (not via scoring macro).
M.PLACEMENT_COMMIT_EFFECT_NAMES = {
	delay_reward_survival = true,
	blockade_adjacent = true,
	escalating_points_bank_init = true,
}

--- Snapshot hooks captured before ``BOARD_APPLY`` (pre-placement territory reads).
M.PLACEMENT_SNAPSHOT_EFFECT_NAMES = {
	territory_to_multiplier_snapshot = true,
}

--- Placement compile hooks that run after ``try_play`` with a board snapshot (before ``BOARD_APPLY``).
M.PLACEMENT_COMPILE_EFFECT_NAMES = {
	anti_capture_immunity = true,
	capture_zero_liberty_enemy = true,
}

--- @param effect_name string|nil
--- @return boolean
function M.is_immediate_placement_effect_name(effect_name)
	return effect_name ~= nil and M.IMMEDIATE_PLACEMENT_EFFECT_NAMES[effect_name] == true
end

--- @param effect_name string|nil
--- @return boolean
function M.is_placement_snapshot_effect_name(effect_name)
	return effect_name ~= nil and M.PLACEMENT_SNAPSHOT_EFFECT_NAMES[effect_name] == true
end

--- @param effect_name string|nil
--- @return boolean
function M.is_placement_commit_effect_name(effect_name)
	return effect_name ~= nil and M.PLACEMENT_COMMIT_EFFECT_NAMES[effect_name] == true
end

--- @param effect_name string|nil
--- @return boolean
function M.is_placement_compile_effect_name(effect_name)
	return effect_name ~= nil and M.PLACEMENT_COMPILE_EFFECT_NAMES[effect_name] == true
end

--- Sorted keys for registry parity checks (resolver ↔ AI).
--- @return string[]
function M.immediate_placement_effect_name_keys()
	local keys = {}
	for name in pairs(M.IMMEDIATE_PLACEMENT_EFFECT_NAMES) do
		keys[#keys + 1] = name
	end
	table.sort(keys)
	return keys
end

--- @param actor string
--- @return string
local function owner_for_side(actor)
	if actor == "white" then
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- @param effect table
--- @param state table
--- @param actor string
--- @param row integer|nil
--- @param col integer|nil
--- @param resolve_fn fun(effect: table): table|nil
--- @param stone_id string|nil
--- @return table|nil
function M.resolve_immediate_placement_effect(effect, state, actor, row, col, resolve_fn, _stone_id)
	if effect.effect_name == "mult_control_streak" then
		if row == nil or col == nil then
			return nil
		end
		local delta = territory_control_rounds.placement_plus_mult_delta(
			state,
			row,
			col,
			owner_for_side(actor)
		)
		if delta == 0 then
			return nil
		end
		return resolve_fn({
			effect_name = "add_mult",
			macro = effect.macro or "playing_stones",
			sub = effect.sub or "mult",
			value = delta,
			priority = effect.priority or 10,
		})
	end
	if effect.effect_name == "money_field_enclosure_payout" or M.is_immediate_placement_effect_name(effect.effect_name) then
		return resolve_fn(effect)
	end
	return nil
end

--- @param stone_def table
--- @param state table
--- @param actor string
--- @param row integer|nil
--- @param col integer|nil
--- @param resolve_fn fun(effect: table): table|nil
--- @return table
function M.resolved_stone_effects_from_def(stone_def, state, actor, row, col, resolve_fn)
	if type(stone_def.behavior) == "function" then
		return stone_def.behavior(state, actor)
	end
	local out = {}
	if not stone_def.effects then
		return out
	end
	local stone_id = stone_def.id
	for i = 1, #stone_def.effects do
		local resolved = M.resolve_immediate_placement_effect(
			stone_def.effects[i],
			state,
			actor,
			row,
			col,
			resolve_fn,
			stone_id
		)
		if resolved then
			out[#out + 1] = resolved
		end
	end
	return out
end

--- @param resolved table|nil
--- @return boolean
function M.is_kamikaze_sacrifice_resolved(resolved)
	return resolved ~= nil and resolved.type == "KAMIKAZE_SACRIFICE"
end

--- @param resolved_effects table
--- @return boolean
function M.has_kamikaze_sacrifice_effect(resolved_effects)
	for i = 1, #resolved_effects do
		if M.is_kamikaze_sacrifice_resolved(resolved_effects[i]) then
			return true
		end
	end
	return false
end

--- @param resolved table
--- @return boolean
function M.is_valid_resolved_placement_effect(resolved)
	if not resolved or type(resolved) ~= "table" then
		return false
	end
	if resolved.type == "ADD_POINTS" or resolved.type == "ADD_MULT" or resolved.type == "ADD_ENERGY" then
		return type(resolved.value) == "number"
	end
	if resolved.type == "KAMIKAZE_SACRIFICE" or resolved.type == "SELF_DESTRUCT_TIMED" then
		return type(resolved.value) == "number"
	end
	if resolved.type == "ADD_MONEY" then
		return type(resolved.value) == "table" and type(resolved.value.amount) == "number"
	end
	if resolved.type == "MONEY_FIELD_ENCLOSURE_PAYOUT" then
		return true
	end
	return false
end

--- Maps resolved placement effect types to ``round_stone_effects`` definition rows.
--- @param resolved_effects table
--- @return table
function M.round_effect_defs_from_resolved(resolved_effects)
	local round = {}
	for i = 1, #resolved_effects do
		local r = resolved_effects[i]
		if r.type == "SELF_DESTRUCT_TIMED" then
			round[i] = {
				effect_name = "self_destruct_timed",
				macro = "playing_stones",
				sub = "points",
				immediate_points = r.value,
				delay_rounds = r.delay_rounds,
				priority = r.priority or 10,
			}
		elseif r.type == "ADD_POINTS" then
			round[i] = {
				effect_name = "add_points",
				macro = "playing_stones",
				sub = "points",
				value = r.value,
				priority = r.priority or 10,
			}
		elseif r.type == "KAMIKAZE_SACRIFICE" then
			round[i] = {
				effect_name = "kamikaze_sacrifice",
				macro = "playing_stones",
				sub = "points",
				value = r.value,
				priority = r.priority or 10,
			}
		elseif r.type == "ADD_MULT" then
			round[i] = {
				effect_name = "add_mult",
				macro = "playing_stones",
				sub = "mult",
				value = r.value,
				priority = r.priority or 10,
			}
		elseif r.type == "ADD_ENERGY" then
			round[i] = {
				effect_name = "add_energy",
				macro = r.macro or "playing_stones",
				sub = r.sub or "points",
				value = r.value,
				priority = r.priority or 10,
			}
		elseif r.type == "ADD_MONEY" then
			round[i] = {
				effect_name = "add_money",
				macro = "playing_stones",
				sub = "points",
				value = r.value,
				priority = r.priority or 10,
			}
		elseif r.type == "MONEY_FIELD_ENCLOSURE_PAYOUT" then
			local def = r._effect_def or {}
			round[i] = {
				effect_name = "money_field_enclosure_payout",
				macro = def.macro or "playing_stones",
				sub = def.sub or "points",
				value = def.value,
				priority = r.priority or def.priority or 10,
			}
		end
	end
	return round
end

--- Runs placement compile factories after legality check (immunity grant, extra capture).
--- @param stone_def table
--- @param state table
--- @param board table
--- @param row integer
--- @param col integer
--- @param actor string
--- @param chain_color integer
--- @param resolve_fn fun(effect: table): table|nil
--- @return table
--- @return integer
function M.apply_placement_compile_effects(stone_def, state, board, row, col, actor, chain_color, resolve_fn)
	local extra_captures = 0
	if not stone_def or not stone_def.effects then
		return board, extra_captures
	end
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		if effect_def.effect_name == "anti_capture_immunity" then
			local resolved = resolve_fn(effect_def)
			if resolved and resolved.apply then
				resolved.apply(state, nil, row, col, board)
			end
		elseif effect_def.effect_name == "capture_zero_liberty_enemy" then
			local new_board, captures = effects_helpers.apply_zero_liberty_enemy_capture(
				board,
				state,
				actor,
				chain_color
			)
			board = new_board
			extra_captures = extra_captures + captures
		end
	end
	return board, extra_captures
end

--- Runs placement snapshot factories before board apply (pre-placement territory reads).
--- @param stone_def table
--- @param state table
--- @param owner string
--- @param row integer
--- @param col integer
--- @param resolve_fn fun(effect: table): table|nil
--- @return nil
function M.apply_placement_snapshot_effects(stone_def, state, owner, row, col, resolve_fn)
	if not stone_def or not stone_def.effects then
		return
	end
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		if M.is_placement_snapshot_effect_name(effect_def.effect_name) then
			local resolved = resolve_fn(effect_def)
			if resolved and resolved.apply then
				resolved.apply(state, owner, row, col)
			end
		end
	end
end

--- Runs placement-commit factories at board apply (timers, blockade, bank init).
--- When the stone has effects, sets ``stone_timer_skip_tick`` so survival timers do not
--- decrement on the placement turn (self-destruct, delay-reward, and shared timer map).
--- @param stone_def table
--- @param state table
--- @param owner string
--- @param row integer
--- @param col integer
--- @param actor string
--- @param resolve_fn fun(effect: table): table|nil
--- @return nil
function M.apply_placement_commit_effects(stone_def, state, owner, row, col, actor, resolve_fn)
	if not stone_def or not stone_def.effects then
		return
	end
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		if M.is_placement_commit_effect_name(effect_def.effect_name) then
			local resolved = resolve_fn(effect_def)
			if resolved and resolved.apply then
				if effect_def.effect_name == "blockade_adjacent" then
					resolved.apply(state, owner, row, col)
					state._blockade_registered_this_action = true
				else
					resolved.apply(state, owner, row, col)
				end
			end
		end
	end
	state.stone_timer_skip_tick = { row = row, col = col }
end

--- Runs ``macro = "on_removed"`` factories when a stone leaves the board.
--- @param stone_def table|nil
--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param captor_side string|nil ``"black"`` | ``"white"`` removing side; nil skips enemy transfer
--- @param resolve_fn fun(effect: table): table|nil
--- @return nil
function M.apply_on_removed_effects(stone_def, state, row, col, cell, captor_side, resolve_fn)
	if not stone_def or not stone_def.effects then
		return
	end
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		if effect_def.macro == "on_removed" then
			local resolved = resolve_fn(effect_def)
			if resolved and resolved.apply then
				resolved.apply(state, row, col, cell, captor_side)
			end
		end
	end
end

--- @param old_board table
--- @param new_board table
--- @return table[]
local function removed_stones_between_boards(old_board, new_board)
	local n = #old_board
	local removed = {}
	for row = 1, n do
		for col = 1, n do
			local old_cell = old_board[row][col]
			local new_cell = new_board[row][col]
			if not board.is_empty(old_cell) and board.is_empty(new_cell) then
				removed[#removed + 1] = { row = row, col = col, cell = old_cell }
			elseif not board.is_empty(old_cell) and not board.is_empty(new_cell) then
				if old_cell.color ~= new_cell.color or old_cell.kind ~= new_cell.kind then
					removed[#removed + 1] = { row = row, col = col, cell = old_cell }
				end
			end
		end
	end
	return removed
end

--- Runs on_removed hooks for every stone cleared by a board replacement.
--- @param state table
--- @param old_board table
--- @param new_board table
--- @param captor_side string|nil
--- @param resolve_fn fun(effect: table): table|nil
--- @return nil
function M.apply_on_removed_for_board_replacement(state, old_board, new_board, captor_side, resolve_fn)
	local removed = removed_stones_between_boards(old_board, new_board)
	for i = 1, #removed do
		local entry = removed[i]
		local stone_def = content.get_stone(entry.cell.kind)
		M.apply_on_removed_effects(stone_def, state, entry.row, entry.col, entry.cell, captor_side, resolve_fn)
	end
end

return M
