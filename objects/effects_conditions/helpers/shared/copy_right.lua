--- Echo copy-right target resolution and child effect application.
--- @module objects.effects_conditions.helpers.shared.copy_right

local config = require("config")
local queries = require("single_game.resolver.helpers.state_queries")

local M = {}

--- Next non-echo stance on the same player's panel to the right of source_slot_index.
function M.resolve_blueprint_target(state, owner, source_slot_index)
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

--- Normalize owner token to config OWNER_BLACK or OWNER_WHITE.
function M.normalize_stance_owner(owner)
	local ob, ow = config.OWNER_BLACK, config.OWNER_WHITE
	if owner == ob or owner == ow then
		return owner
	end
	return ((owner == "white" or owner == ow) and ow) or ob
end

--- Resolves the first non-echo stance to the right of the Echo row, plus its definition.
function M.get_copy_right_target(state)
	local stance_entry = queries.source_stance_entry(state)
	if not stance_entry then
		return nil, nil, nil
	end
	local owner_key = M.normalize_stance_owner(stance_entry.owner)
	local target = M.resolve_blueprint_target(state, owner_key, stance_entry.slot_index)
	if not target then
		return nil, nil, nil
	end
	local target_owner = M.normalize_stance_owner(target.owner)
	local defs = require("objects.definitions.stances")
	local target_def = defs[target.type]
	if not target_def or not target_def.effects then
		return nil, nil, nil
	end
	return target, target_owner, target_def
end

local function copied_child_matches_active_phase(effect_def, active_phase, territory_step)
	local scoring_phases = require("single_game.resolver.scoring_phases")
	local _, child_phase, child_step = scoring_phases.parse_effect_scheduling(effect_def)
	if not child_phase or child_phase ~= active_phase then
		return false
	end
	if active_phase == "territory" and territory_step and child_step ~= territory_step then
		return false
	end
	if active_phase == "territory" and territory_step and not child_step then
		return false
	end
	return true
end

--- Scans target_def.effects for children matching the active scoring phase, skipping recursive copy_right rows.
function M.get_target_effects(state, target_def, resolve_effect)
	local active_phase = queries.resolution_phase(state)
	local territory_step = queries.resolution_territory_step(state)
	if not target_def or not target_def.effects or not active_phase then
		return nil
	end
	local resolved_effects = {}
	for i = 1, #target_def.effects do
		local effect_def = target_def.effects[i]
		if effect_def.effect_name ~= "copy_right_effect" then
			local resolved = resolve_effect(effect_def)
			if resolved and resolved.apply and copied_child_matches_active_phase(effect_def, active_phase, territory_step) then
				resolved.phase = active_phase
				resolved_effects[#resolved_effects + 1] = resolved
			end
		end
	end
	if #resolved_effects == 0 then
		return nil
	end
	return resolved_effects
end

--- Temporarily repoints state.resolution metadata at the copied stance for nested child effects.
function M.with_resolution_for_copied_stance_target(state, target, fn)
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

--- For each resolved child from an Echo copy, evaluate conditions and apply via the runner.
function M.apply_copied_effect(state, target, target_owner, resolved_effects)
	local run = require("objects.effects_conditions.run")
	for i = 1, #resolved_effects do
		local resolved = resolved_effects[i]
		M.with_resolution_for_copied_stance_target(state, target, function()
			run.apply_effect(resolved, state, target_owner)
		end)
	end
end

--- Apply copy-right echo by resolving and running child effects from the target stance.
function M.apply_copy_right(state, resolve_effect)
	local target, target_owner, target_def = M.get_copy_right_target(state)
	if not target or not target_def then
		return
	end
	local resolved_effects = M.get_target_effects(state, target_def, resolve_effect)
	if not resolved_effects then
		return
	end
	M.apply_copied_effect(state, target, target_owner, resolved_effects)
end

return M
