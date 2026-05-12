--- Registered animation builder implementations (``function(state, args)``). Consumed only by ``objects.animations``
--- factory wiring; gameplay uses ``add_animation(name)(state, args)``.
--- @module objects.animations_definitions

local animations_helper = require("objects.animations_helper")

local STEEL_SYNC_DEF_ID = "stance_special_steel_sync"

local M = {}

--- Steel sync: stance shake + sequential hand floats (timing via ``sequence_id`` + drain scheduler).
--- **Args**: ``owner``, ``steel_hand_indices``, ``factor`` (numeric multiplier factor for ``×`` label, e.g. ``1.5``).
--- Emits nothing unless ``state.resolution`` indicates ``stance_special_steel_sync`` stance.
--- @param state table
--- @param args table
--- @return nil
function M.steel_sync_mult(state, args)
	local owner = args.owner
	local steel_hand_indices = args.steel_hand_indices
	local factor = args.factor
	local r = state.resolution
	if not r or r.source_def_id ~= STEEL_SYNC_DEF_ID or r.source_object_type ~= "stance" then
		return
	end
	if not steel_hand_indices or #steel_hand_indices == 0 or type(factor) ~= "number" then
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
	ev[#ev + 1] = {
		type = "stance_shake",
		sequence_id = seq_id,
		start_delay_ms = 0,
		owner = owner,
		stance_def_id = STEEL_SYNC_DEF_ID,
		stance_slot_index = stance_slot,
		stance_instance_id = inst,
	}
	for i = 1, #steel_hand_indices do
		ev[#ev + 1] = {
			type = "hand_card_float_text",
			sequence_id = seq_id,
			start_delay_ms = 0,
			duration_ms = float_step_ms,
			owner = owner,
			hand_index = steel_hand_indices[i],
			text = label,
		}
	end
end

return M
