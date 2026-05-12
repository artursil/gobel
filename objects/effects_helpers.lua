--- Shared helpers for ``objects.effects`` (blueprint copy-right, board stone distance layout). Kept separate so ``objects.effects`` stays effect builders and dispatch only.
--- @module objects.effects_helpers

local config = require("config")
local queries = require("single_game.resolver.state_queries")

local H = {}

--- Next non-blueprint stance on the **same player's** panel to the right of ``source_slot_index``.
--- @param state table
--- @param owner string Normalized ``config`` owner token for the blueprint row.
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
		if row.type ~= "stance_blueprint" then
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

--- Resolves the first non-blueprint stance to the right of the blueprint row, plus its definition.
--- The copied lane belongs to the same side as the blueprint, so the normalized owner matches the blueprint owner; child effects still need ``source_def_id`` / optional instance metadata to point at the copied stance type for conditions and telemetry.
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

--- Scans ``target_def.effects`` for children that participate in the active scoring ``phase`` (from ``state.resolution``), skipping recursive ``copy_right_effect`` rows. Each matching definition is passed through ``resolve_effect`` (typically ``objects.effects.resolve``) before any ``apply`` runs. Every returned payload has ``phase`` set to ``phase`` so the resolved object matches the resolver's current phase even when a builder supplied a different default. Order follows the stance definition. Returns ``nil`` when there is nothing to run (missing inputs, empty list, or no child matches the phase).
--- @param state table
--- @param target_def table Stance definition from ``objects.definitions.stances`` (expects an ``effects`` array).
--- @param resolve_effect fun(effect_def: table): table|nil
--- @return table|nil Sequential list of resolved runtime effect tables, each with ``apply``; or ``nil`` if none.
function H.get_target_effects(state, target_def, resolve_effect)
	local phase = queries.resolution_phase(state)
	if not target_def or not target_def.effects or not phase then
		return nil
	end
	local resolved_effects = {}
	for i = 1, #target_def.effects do
		local effect_def = target_def.effects[i]
		if effect_def.effect_name ~= "copy_right_effect" then
			local resolved = resolve_effect(effect_def)
			if resolved and resolved.apply and resolved.phase == phase then
				resolved.phase = phase
				resolved_effects[#resolved_effects + 1] = resolved
			end
		end
	end
	if #resolved_effects == 0 then
		return nil
	end
	return resolved_effects
end

--- Temporarily repoints ``state.resolution`` metadata at the copied stance so nested child effects and conditions see the correct ``source_def_id`` / instance while ``source_owner`` stays the lane owner (unchanged from the blueprint row, which is always the same side as the copy target).
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

--- For each resolved child from a blueprint copy, temporarily repoints ``state.resolution`` at ``target``, evaluates conditions, and applies the child with ``target_owner``.
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
