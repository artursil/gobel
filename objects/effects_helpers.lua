--- Shared helpers for ``objects.effects`` (Echo copy-right, board stone distance layout). Kept separate so ``objects.effects`` stays effect builders and dispatch only.
--- @module objects.effects_helpers

local config = require("config")
local energy = require("energy")
local queries = require("single_game.resolver.state_queries")

local H = {}

--- Side whose turn just ended for the active ``end_of_turn`` resolve.
--- Uses explicit resolver hook when set; otherwise infers from ``to_play`` for round-advance test paths.
--- @param state table
--- @return string|nil ``config.OWNER_BLACK`` | ``config.OWNER_WHITE``
function H.active_end_of_turn_owner(state)
	if state._end_of_turn_owner == config.OWNER_BLACK or state._end_of_turn_owner == config.OWNER_WHITE then
		return state._end_of_turn_owner
	end
	local to_play = state.to_play
	if to_play == "white" then
		return config.OWNER_BLACK
	end
	if to_play == "black" then
		return config.OWNER_WHITE
	end
	return nil
end

--- Next non-echo stance on the **same player's** panel to the right of ``source_slot_index``.
--- @param state table
--- @param owner string Normalized ``config`` owner token for the Echo row.
--- @param source_slot_index integer|nil 1-based lane on that player's panel; nil yields no target.
--- @return table|nil Lane ``{ type, owner, instance?, slot_index }``.
function H.resolve_blueprint_target(state, owner, source_slot_index)
	if not owner or type(source_slot_index) ~= "number" then
		return nil
	end
	local stance_order_mod = require("single_game.resolver.stance_order")
	local side = owner == config.OWNER_WHITE and "white" or "black"
	local slots = stance_order_mod.canonical_stance_slots_for_side(state, side)
	for si = source_slot_index + 1, #slots do
		local row = slots[si]
		if row.type ~= "stance_echo" then
			return {
				type = row.type,
				owner = row.owner,
				instance = nil,
				slot_index = row.slot_index,
			}
		end
	end
	return nil
end

--- @param owner string
--- @return string
function H.normalize_stance_owner(owner)
	local ob, ow = config.OWNER_BLACK, config.OWNER_WHITE
	if owner == ob or owner == ow then
		return owner
	end
	return ((owner == "white" or owner == ow) and ow) or ob
end

--- Resolves the first non-echo stance to the right of the Echo row, plus its definition.
--- The copied lane belongs to the same side as Echo, so the normalized owner matches the Echo owner; child effects still need ``source_def_id`` / optional instance metadata to point at the copied stance type for conditions and telemetry.
--- @param state table
--- @return table|nil target Lane table (``type``, ``owner``, optional ``instance``).
--- @return string|nil target_owner Normalized ``config`` owner token.
--- @return table|nil target_def Entry from ``objects.definitions.stances`` for ``target.type``, including ``effects``.
function H.get_copy_right_target(state)
	local stance_entry = queries.source_stance_entry(state)
	if not stance_entry then
		return nil, nil, nil
	end
	local owner_key = H.normalize_stance_owner(stance_entry.owner)
	local target = H.resolve_blueprint_target(state, owner_key, stance_entry.slot_index)
	if not target then
		return nil, nil, nil
	end
	local target_owner = H.normalize_stance_owner(target.owner)
	local defs = require("objects.definitions.stances")
	local target_def = defs[target.type]
	if not target_def or not target_def.effects then
		return nil, nil, nil
	end
	return target, target_owner, target_def
end

--- Whether a copied stance child runs in the active resolve sub (ignores the child's macro).
--- @param effect_def table
--- @param active_sub string
--- @param territory_step string|nil
--- @return boolean
local function copied_child_matches_active_sub(effect_def, active_sub, territory_step)
	local scoring_phases = require("single_game.resolver.scoring_phases")
	local _, child_sub, child_step = scoring_phases.parse_effect_phase(effect_def)
	if not child_sub or child_sub ~= active_sub then
		return false
	end
	if active_sub == "territory" and territory_step and child_step ~= territory_step then
		return false
	end
	if active_sub == "territory" and territory_step and not child_step then
		return false
	end
	return true
end

--- Scans ``target_def.effects`` for children matching the active scoring sub (from ``state.resolution``), skipping recursive ``copy_right_effect`` rows. Copied children ignore their own macro so e.g. ``before_turn.points`` can apply during ``playing_stones.points``. Returns ``nil`` when there is nothing to run.
--- @param state table
--- @param target_def table Stance definition from ``objects.definitions.stances`` (expects an ``effects`` array).
--- @param resolve_effect fun(effect_def: table): table|nil
--- @return table|nil Sequential list of resolved runtime effect tables, each with ``apply``; or ``nil`` if none.
function H.get_target_effects(state, target_def, resolve_effect)
	local active_sub = queries.resolution_sub(state)
	local territory_step = queries.resolution_territory_step(state)
	if not target_def or not target_def.effects or not active_sub then
		return nil
	end
	local resolved_effects = {}
	for i = 1, #target_def.effects do
		local effect_def = target_def.effects[i]
		if effect_def.effect_name ~= "copy_right_effect" then
			local resolved = resolve_effect(effect_def)
			if resolved and resolved.apply and copied_child_matches_active_sub(effect_def, active_sub, territory_step) then
				resolved.sub = active_sub
				resolved.phase = active_sub
				resolved_effects[#resolved_effects + 1] = resolved
			end
		end
	end
	if #resolved_effects == 0 then
		return nil
	end
	return resolved_effects
end

--- Temporarily repoints ``state.resolution`` metadata at the copied stance so nested child effects and conditions see the correct ``source_def_id`` / instance while ``source_owner`` stays the lane owner (unchanged from the Echo row, which is always the same side as the copy target).
--- Only fields that this copy path mutates are saved and restored: global ``source_stance_index`` is cleared because the synthetic apply is not tied to a single derived-order row; definition and instance id follow the target row.
--- @param state table
--- @param target table Copied stance lane row (``type``, optional ``instance``).
--- @param fn function Callback invoked while resolution points at ``target``.
--- @return nil
function H.with_resolution_for_copied_stance_target(state, target, fn)
	local resolution = queries.ensure_resolution(state)
	local prev_stance_index = resolution.source_stance_index
	local prev_instance_id = resolution.source_instance_id
	local prev_def_id = resolution.source_def_id
	resolution.source_stance_index = nil
	resolution.source_instance_id = target.instance and target.instance.instance_id or nil
	resolution.source_def_id = target.type
	resolution.source_object_type = "stance"
	fn()
	resolution.source_stance_index = prev_stance_index
	resolution.source_instance_id = prev_instance_id
	resolution.source_def_id = prev_def_id
end

--- For each resolved child from an Echo copy, temporarily repoints ``state.resolution`` at ``target``, evaluates conditions, and applies the child with ``target_owner``.
--- @param state table
--- @param target table Copied stance lane row (``type``, optional ``instance``).
--- @param target_owner string Normalized owner token for child ``apply``.
--- @param resolved_effects table Sequential list from ``resolve_copy_right_child_effects_for_phase``.
--- @return nil
function H.apply_copied_effect(state, target, target_owner, resolved_effects)
	local conditions_mod = require("objects.conditions")
	for i = 1, #resolved_effects do
		local resolved = resolved_effects[i]
		H.with_resolution_for_copied_stance_target(state, target, function()
			if conditions_mod.eval_all(resolved.conditions, state) then
				resolved.apply(state, target_owner)
			end
		end)
	end
end

--- Stone key generator for distance modifier indexing.
--- @param row integer
--- @param col integer
--- @return integer
function H.stone_key(row, col)
	return row * 100 + col
end

--- @param row integer
--- @param col integer
--- @return string
function H.stone_cell_key(row, col)
	return row .. ":" .. col
end

--- Reads per-cell stored value used by escalating bank stones.
--- @param state table
--- @param row integer
--- @param col integer
--- @return number|nil
function H.stone_stored_value(state, row, col)
	local cell = state.board and state.board[row] and state.board[row][col]
	if type(cell) == "table" and cell.stored_value ~= nil then
		return cell.stored_value
	end
	return nil
end

--- Writes per-cell stored value used by escalating bank stones.
--- @param state table
--- @param row integer
--- @param col integer
--- @param value number
--- @return nil
function H.set_stone_stored_value(state, row, col, value)
	local row_cells = state.board and state.board[row]
	local cell = row_cells and row_cells[col]
	if type(cell) == "table" then
		cell.stored_value = value
	end
end

--- Grant energy to the player identified by owner token (clamped to energy_max).
--- @param state table
--- @param owner string config owner token (B/W)
--- @param amount number
--- @return nil
function H.gain_player_energy(state, owner, amount)
	local side = owner == config.OWNER_WHITE and "white" or "black"
	local player = require("match_state").player_for_color(state, side)
	if not player then
		return
	end
	energy.gain(player, amount)
end

--- Adds permanent per-cell point bonus for board stone scoring.
--- @param state table
--- @param row integer
--- @param col integer
--- @param points integer
--- @return nil
function H.add_cell_points_bonus(state, row, col, points)
	if points == 0 then
		return
	end
	state.board_stone_modifiers = state.board_stone_modifiers or {}
	local key = row .. ":" .. col
	state.board_stone_modifiers[key] = state.board_stone_modifiers[key] or { points_bonus = 0 }
	state.board_stone_modifiers[key].points_bonus = state.board_stone_modifiers[key].points_bonus + points
end

--- Apply distance bonus for a stone across all tiles.
--- @param stone_def table
--- @param current_state table
--- @param key integer
--- @param n integer
--- @param distance_bonus_value integer
--- @return nil
function H.apply_distance_bonus_for_stone(stone_def, current_state, key, n, distance_bonus_value)
	current_state.distance_modifiers = current_state.distance_modifiers
		or {
			default_bonus = 0,
			by_stone = {},
			get_bonus = nil,
		}
	current_state.distance_modifiers.by_stone = current_state.distance_modifiers.by_stone or {}
	local by_tile = {}
	for tr = 1, n do
		for tc = 1, n do
			by_tile[tr * 100 + tc] = distance_bonus_value
		end
	end
	current_state.distance_modifiers.by_stone[key] = by_tile
end

return H
