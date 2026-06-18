--- Card hand selection, targeting, drag-to-play, and validation mirror for human card UI.

local board = require("board")
local content = require("content")
local deck = require("deck")
local energy = require("energy")
local layout_mod = require("layout")
local match_state = require("match_state")
local resolver = require("resolver")

local M = {}

local PHASE_IDLE = "idle"
local PHASE_CARD_SELECTED = "card_selected"
local PHASE_DISCARD_ARMED = "discard_targets_armed"
local PHASE_DRAG_CONFIRM = "drag_to_confirm"
local PHASE_DRAG_ARROW = "drag_target_arrow"

local DRAG_MOVE_THRESHOLD_SQ = 64

--- @param ref table
--- @return string
local function target_key(ref)
	if ref.object_type == "stone" then
		return table.concat({ "stone", tostring(ref.row), tostring(ref.col) }, ":")
	end
	if ref.object_type == "card" then
		return table.concat({ "card", tostring(ref.owner), tostring(ref.hand_index) }, ":")
	end
	if ref.object_type == "stance" then
		return table.concat({ "stance", tostring(ref.owner), tostring(ref.lane), tostring(ref.slot_index) }, ":")
	end
	return ""
end

--- @param error_text string|nil
--- @return string
local function map_validation_reason(error_text)
	if error_text == "Target missing required tags" or error_text == "Target missing one of required tags" then
		return "Invalid target: missing required tags"
	end
	if error_text == "Target owner mismatch" then
		return "Invalid target: wrong owner"
	end
	if error_text == "Target object type mismatch" then
		return "Invalid target: wrong target type"
	end
	if error_text == "Target has excluded tag" then
		return "Invalid target: excluded target"
	end
	if error_text == "Too many selected targets" then
		return "Target limit reached"
	end
	if error_text and error_text ~= "" then
		return "Invalid target: " .. error_text
	end
	return ""
end

--- @param ref table
--- @return string
local function target_display_label(ref)
	if ref.object_type == "stone" then
		return string.format("Stone (%d,%d)", ref.row or -1, ref.col or -1)
	end
	if ref.object_type == "card" then
		return string.format("Card #%d", ref.hand_index or -1)
	end
	if ref.object_type == "stance" then
		return string.format("Stance %s #%d", tostring(ref.lane), ref.slot_index or -1)
	end
	return "Target"
end

--- @param card_def table|nil
--- @return boolean
local function card_targets_hand(card_def)
	return card_def and card_def.target_object_type == "card"
end

--- @param card_def table|nil
--- @return boolean
local function card_targets_stone(card_def)
	return card_def and card_def.target_object_type == "stone"
end

--- @param card_def table|nil
--- @param hand_target_phase string|nil
--- @return string
local function card_action_button_label(card_def, hand_target_phase)
	if hand_target_phase == "armed" then
		return "Confirm"
	end
	if not card_def then
		return "Use"
	end
	if card_def.play_mode == "instant" or card_def.play_mode == nil then
		return "Confirm"
	end
	return "Use"
end

--- @param targets table
--- @return table
local function copy_targets(targets)
	local out = {}
	for i = 1, #targets do
		out[i] = targets[i]
	end
	return out
end

--- @return table
local function empty_internal()
	return {
		selected_index = nil,
		selected_targets = {},
		popped_target_indices = {},
		can_use = false,
		validation_error = nil,
		validation_reason = "",
		requirement_text = "",
		status_text = "",
		action_button_label = "Use",
		selected_target_labels = {},
		target_chip_rects = {},
		invalid_target_feedback = nil,
		drag_mode = "none",
		drag_active = false,
		drag_targeting = false,
		drag_index = nil,
		start_x = 0,
		start_y = 0,
		current_x = 0,
		current_y = 0,
		drag_arrow_from_x = 0,
		drag_arrow_from_y = 0,
		drag_arrow_to_x = 0,
		drag_arrow_to_y = 0,
		drag_target_ref = nil,
		drag_target_valid = false,
		drag_target_error = nil,
		moved = false,
		hand_target_phase = nil,
		armed_hand_index = nil,
		armed_card_id = nil,
	}
end

--- @param s table
--- @return string
local function compute_phase(s)
	if s.drag_active and s.moved then
		if s.drag_mode == "target_arrow" then
			return PHASE_DRAG_ARROW
		end
		if s.drag_mode == "to_confirm" then
			return PHASE_DRAG_CONFIRM
		end
	end
	if s.hand_target_phase == "armed" then
		return PHASE_DISCARD_ARMED
	end
	if s.selected_index then
		return PHASE_CARD_SELECTED
	end
	return PHASE_IDLE
end

--- @param s table
--- @param match table
--- @return table|nil
local function active_player(s, match)
	return match and match_state.player_for_color(match, match.to_play) or nil
end

--- @param s table
--- @param active table
--- @return table|nil card_def
--- @return string|nil card_id
local function current_selected_card(s, active)
	local idx = s.selected_index
	local card_id = idx and active.cards.hand.ids[idx] or nil
	if not card_id then
		return nil, nil
	end
	return content.get_card(card_id), card_id
end

--- @param s table
--- @param active table
--- @return table|nil
local function armed_hand_target_card_def(s, active)
	if s.armed_card_id then
		return content.get_card(s.armed_card_id)
	end
	if not active or not s.armed_hand_index then
		return nil
	end
	local card_id = active.cards.hand.ids[s.armed_hand_index]
	return card_id and content.get_card(card_id) or nil
end

--- @param active table
--- @param hand_index integer
--- @param card_def table
--- @return boolean
local function can_arm_hand_target_card(active, hand_index, card_def)
	if not active or not hand_index or not card_def then
		return false
	end
	if not deck.can_play_from_hand(active.cards, hand_index) then
		return false
	end
	return energy.can_spend(active, card_def.energy_cost)
end

--- @param s table
--- @return nil
local function sync_popped_target_indices(s)
	s.popped_target_indices = {}
	for i = 1, #s.selected_targets do
		local ref = s.selected_targets[i]
		if ref.object_type == "card" and ref.hand_index then
			s.popped_target_indices[ref.hand_index] = true
		end
	end
end

--- @param s table
--- @return table
local function build_card_target_hint_cells(s)
	local hints = {}
	for i = 1, #s.selected_targets do
		local ref = s.selected_targets[i]
		if ref.object_type == "stone" then
			hints[target_key(ref)] = true
		end
	end
	return hints
end

--- @param controller table
--- @param ctx table
--- @return nil
local function refresh(controller, ctx)
	local s = controller._state
	local match = ctx.match
	local layout = ctx.layout
	local active = active_player(s, match)
	if not active then
		return
	end
	s.action_button_label = "Use"
	if not s.selected_index and s.hand_target_phase ~= "armed" then
		s.can_use = false
		s.validation_error = nil
		s.validation_reason = ""
		s.status_text = s.status_text or ""
		s.requirement_text = ""
		s.selected_target_labels = {}
		s.target_chip_rects = {}
		s.popped_target_indices = {}
		return
	end
	local card_def
	if s.hand_target_phase == "armed" then
		card_def = armed_hand_target_card_def(s, active)
		if not card_def then
			s.hand_target_phase = nil
			s.armed_hand_index = nil
			s.armed_card_id = nil
			s.selected_targets = {}
			s.can_use = false
			s.action_button_label = "Use"
			return
		end
	else
		card_def = current_selected_card(s, active)
		if not card_def then
			s.selected_index = nil
			s.selected_targets = {}
			s.can_use = false
			s.validation_error = nil
			s.validation_reason = ""
			s.status_text = ""
			s.requirement_text = ""
			s.selected_target_labels = {}
			s.target_chip_rects = {}
			return
		end
	end
	local validation
	if s.hand_target_phase == "armed" then
		validation = resolver.validate_card_targets(card_def, s.selected_targets, match, match.to_play)
		s.can_use = validation.ok
	elseif card_targets_hand(card_def) then
		s.can_use = can_arm_hand_target_card(active, s.selected_index, card_def)
		validation = { ok = s.can_use, error = s.can_use and nil or "Insufficient energy" }
	else
		validation = resolver.validate_card_targets(card_def, s.selected_targets, match, match.to_play)
		s.can_use = validation.ok
	end
	s.validation_error = validation.error
	s.validation_reason = validation.ok and "" or map_validation_reason(validation.error)
	s.action_button_label = card_action_button_label(card_def, s.hand_target_phase)
	sync_popped_target_indices(s)
	local min_targets = card_def.min_targets or (card_def.play_mode == "target_single" and 1 or 0)
	local max_targets = card_def.max_targets or min_targets
	if s.hand_target_phase == "armed" or card_targets_hand(card_def) then
		local requirement_suffix = ""
		if min_targets == max_targets then
			requirement_suffix = string.format(" (need exactly %d)", max_targets)
		elseif min_targets > 0 then
			requirement_suffix = string.format(" (min %d)", min_targets)
		end
		if s.hand_target_phase == "armed" then
			s.requirement_text = string.format("Targets: %d/%d%s", #s.selected_targets, max_targets, requirement_suffix)
		else
			s.requirement_text = "Press Use to choose discards"
		end
	elseif card_def.play_mode == "instant" or card_def.play_mode == nil then
		s.requirement_text = "No target required"
	else
		local requirement_suffix = ""
		if min_targets == max_targets then
			requirement_suffix = string.format(" (need exactly %d)", max_targets)
		elseif min_targets > 0 then
			requirement_suffix = string.format(" (min %d)", min_targets)
		end
		s.requirement_text = string.format("Targets: %d/%d%s", #s.selected_targets, max_targets, requirement_suffix)
	end
	s.selected_target_labels = {}
	for i = 1, #s.selected_targets do
		s.selected_target_labels[i] = target_display_label(s.selected_targets[i])
	end
	if card_targets_hand(card_def) then
		s.target_chip_rects = {}
	else
		s.target_chip_rects = layout_mod.card_target_chip_rects(layout, #s.selected_targets)
	end
end

--- @param s table
--- @return table
local function final_targets_with_drag_ref(s)
	local final_targets = copy_targets(s.selected_targets)
	if not s.drag_target_ref then
		return final_targets
	end
	local key = target_key(s.drag_target_ref)
	for i = 1, #final_targets do
		if target_key(final_targets[i]) == key then
			return final_targets
		end
	end
	final_targets[#final_targets + 1] = s.drag_target_ref
	return final_targets
end

--- @param s table
--- @param ref table
--- @param message string|nil
--- @return nil
local function flash_invalid_target(s, ref, message)
	s.status_text = message or ""
	s.invalid_target_feedback = {
		key = target_key(ref),
		object_type = ref.object_type,
		row = ref.row,
		col = ref.col,
		hand_index = ref.hand_index,
		remaining = 0.55,
	}
end

--- @param controller table
--- @param ctx table
--- @return nil
local function clear_after_play(controller, ctx)
	local s = controller._state
	s.selected_index = nil
	s.selected_targets = {}
	s.popped_target_indices = {}
	s.status_text = ""
	s.drag_mode = "none"
	s.hand_target_phase = nil
	s.armed_hand_index = nil
	s.armed_card_id = nil
	refresh(controller, ctx)
end

--- @param controller table
--- @param ctx table
--- @return boolean
local function commit_selected_card(controller, ctx)
	local s = controller._state
	local play_index = s.armed_hand_index or s.selected_index
	if not play_index or not s.can_use then
		return false
	end
	local ok = ctx.play_card(ctx.match, play_index, s.selected_targets)
	if ok then
		clear_after_play(controller, ctx)
	end
	return ok
end

--- @param controller table
--- @param ctx table
--- @return boolean
local function arm_hand_target_card(controller, ctx)
	local s = controller._state
	local match = ctx.match
	local active = active_player(s, match)
	if s.hand_target_phase == "armed" or not s.selected_index or not s.can_use or not active then
		return false
	end
	local card_id = active.cards.hand.ids[s.selected_index]
	if not card_id then
		return false
	end
	s.hand_target_phase = "armed"
	s.armed_hand_index = s.selected_index
	s.armed_card_id = card_id
	s.selected_index = nil
	s.selected_targets = {}
	s.popped_target_indices = {}
	s.drag_active = false
	s.drag_mode = "none"
	s.drag_targeting = false
	s.drag_index = nil
	s.moved = false
	refresh(controller, ctx)
	return true
end

--- @param controller table
--- @param ctx table
--- @return boolean
local function activate_action_button(controller, ctx)
	local s = controller._state
	if not s.can_use then
		return false
	end
	local active = active_player(s, ctx.match)
	if s.hand_target_phase == "armed" then
		return commit_selected_card(controller, ctx)
	end
	local card_def = current_selected_card(s, active)
	if card_def and card_targets_hand(card_def) then
		return arm_hand_target_card(controller, ctx)
	end
	return commit_selected_card(controller, ctx)
end

--- @param controller table
--- @param ref table
--- @param ctx table
--- @return nil
local function toggle_selected_target(controller, ref, ctx)
	local s = controller._state
	local match = ctx.match
	local key = target_key(ref)
	for i = 1, #s.selected_targets do
		if target_key(s.selected_targets[i]) == key then
			table.remove(s.selected_targets, i)
			s.status_text = ""
			refresh(controller, ctx)
			return
		end
	end
	local active = active_player(s, match)
	local card_def = s.hand_target_phase == "armed" and armed_hand_target_card_def(s, active)
		or current_selected_card(s, active)
	if not card_def then
		return
	end
	if ref.object_type == "card" and ref.hand_index == s.selected_index then
		return
	end
	if ref.object_type == "card" and ref.hand_index == s.armed_hand_index then
		return
	end
	local candidate_validation =
		resolver.validate_card_target_candidate(card_def, s.selected_targets, ref, match, match.to_play)
	if not candidate_validation.ok then
		flash_invalid_target(s, ref, map_validation_reason(candidate_validation.error))
		refresh(controller, ctx)
		return
	end
	s.selected_targets[#s.selected_targets + 1] = ref
	s.status_text = ""
	refresh(controller, ctx)
end

--- @param x number
--- @param y number
--- @param active table
--- @param match table
--- @param layout table
--- @param card_def table|nil
--- @return table|nil candidate
--- @return number tx
--- @return number ty
local function build_drag_candidate_target(x, y, active, match, layout, card_def)
	if not card_def then
		return nil, x, y
	end
	if card_def.target_object_type == "stone" then
		local row, col = layout_mod.pixel_to_grid(layout, x, y)
		if not row or not col then
			return nil, x, y
		end
		local cell = match.board[row] and match.board[row][col]
		if not cell or board.is_empty(cell) then
			return nil, x, y
		end
		local cx, cy = layout_mod.grid_to_pixel(layout, row, col)
		return { object_type = "stone", row = row, col = col }, cx, cy
	end
	if card_def.target_object_type == "card" then
		local hand_count = #active.cards.hand.ids
		local hand_index = layout_mod.hand_index_at(layout, x, y, hand_count)
		if not hand_index then
			return nil, x, y
		end
		local slots = layout_mod.hand_fan_slots(layout, hand_count)
		local slot = slots[hand_index]
		local cx = slot and (slot.x + slot.w * 0.5) or x
		local cy = slot and (slot.y + slot.h * 0.5) or y
		return { object_type = "card", owner = match.to_play, hand_index = hand_index }, cx, cy
	end
	return nil, x, y
end

--- @param controller table
--- @param x number
--- @param y number
--- @param ctx table
--- @return nil
local function update_card_drag_targeting(controller, x, y, ctx)
	local s = controller._state
	if not s.drag_active or s.drag_mode ~= "target_arrow" then
		return
	end
	local match = ctx.match
	local layout = ctx.layout
	local active = active_player(s, match)
	if not active then
		return
	end
	local hand_count = #active.cards.hand.ids
	local anchor_index = s.selected_index or s.drag_index
	s.drag_arrow_from_x, s.drag_arrow_from_y = layout_mod.card_focus_center(layout, anchor_index, hand_count)
	local card_def = current_selected_card(s, active)
	local candidate, tx, ty = build_drag_candidate_target(x, y, active, match, layout, card_def)
	s.drag_arrow_to_x = tx
	s.drag_arrow_to_y = ty
	s.drag_target_ref = nil
	s.drag_target_valid = false
	s.drag_target_error = nil
	if not candidate then
		return
	end
	local candidate_targets = copy_targets(s.selected_targets)
	local already_selected = false
	local candidate_key = target_key(candidate)
	for i = 1, #candidate_targets do
		if target_key(candidate_targets[i]) == candidate_key then
			already_selected = true
			break
		end
	end
	if not already_selected then
		candidate_targets[#candidate_targets + 1] = candidate
	end
	local validation = resolver.validate_card_targets(card_def, candidate_targets, match, match.to_play)
	s.drag_target_ref = candidate
	s.drag_target_valid = validation.ok
	s.drag_target_error = validation.error
end

--- @param controller table
--- @param ctx table
--- @return table
local function build_public_state(controller, ctx)
	local s = controller._state
	refresh(controller, ctx)
	local phase = compute_phase(s)
	local out = {
		phase = phase,
		selected_index = s.selected_index,
		selected_targets = copy_targets(s.selected_targets),
		popped_target_indices = {},
		can_use = s.can_use,
		validation_error = s.validation_error,
		validation_reason = s.validation_reason,
		requirement_text = s.requirement_text,
		status_text = s.status_text,
		action_button_label = s.action_button_label,
		selected_target_labels = copy_targets(s.selected_target_labels),
		target_chip_rects = s.target_chip_rects,
		invalid_target_feedback = s.invalid_target_feedback,
		card_target_hint_cells = build_card_target_hint_cells(s),
		drag_mode = s.drag_mode,
		drag_active = s.drag_active,
		drag_targeting = s.drag_targeting,
		drag_index = s.drag_index,
		start_x = s.start_x,
		start_y = s.start_y,
		current_x = s.current_x,
		current_y = s.current_y,
		drag_arrow_from_x = s.drag_arrow_from_x,
		drag_arrow_from_y = s.drag_arrow_from_y,
		drag_arrow_to_x = s.drag_arrow_to_x,
		drag_arrow_to_y = s.drag_arrow_to_y,
		drag_target_ref = s.drag_target_ref,
		drag_target_valid = s.drag_target_valid,
		drag_target_error = s.drag_target_error,
		moved = s.moved,
		hand_target_phase = s.hand_target_phase,
		armed_hand_index = s.armed_hand_index,
		armed_card_id = s.armed_card_id,
	}
	for k, v in pairs(s.popped_target_indices) do
		out.popped_target_indices[k] = v
	end
	return out
end

--- Creates a card play controller with idle internal state.
--- @return table
function M.new()
	return setmetatable({ _state = empty_internal() }, { __index = M })
end

--- Resets selection, targeting, drag, and armed-discard flow to idle.
--- @param self table
--- @return nil
function M.reset(self)
	self._state = empty_internal()
end

--- Recomputes can_use, labels, requirement text, and chip layout from resolver validation.
--- @param self table
--- @param ctx table match, layout, play_card callback
--- @return nil
function M.refresh(self, ctx)
	refresh(self, ctx)
end

--- Returns a snapshot for render injection (does not write match targeting fields).
--- @param self table
--- @param ctx table
--- @return table
function M.state(self, ctx)
	return build_public_state(self, ctx)
end

--- Ticks invalid-target feedback timer.
--- @param self table
--- @param dt number
--- @return nil
function M.update(self, dt)
	local feedback = self._state.invalid_target_feedback
	if not feedback then
		return
	end
	feedback.remaining = feedback.remaining - dt
	if feedback.remaining <= 0 then
		self._state.invalid_target_feedback = nil
	end
end

--- Attempts play via button, drag-to-confirm, or drag-arrow release.
--- @param self table
--- @param source string "button" | "drag_confirm" | "drag_arrow"
--- @param ctx table
--- @return boolean
function M.try_commit(self, source, ctx)
	refresh(self, ctx)
	local s = self._state
	if source == "drag_arrow" then
		if not s.drag_target_ref or not s.drag_target_valid or not s.drag_index then
			return false
		end
		local targets = final_targets_with_drag_ref(s)
		local ok = ctx.play_card(ctx.match, s.drag_index, targets)
		if ok then
			clear_after_play(self, ctx)
		end
		return ok
	end
	if source == "button" or source == "drag_confirm" then
		return activate_action_button(self, ctx)
	end
	return false
end

--- Handles hand card press, Use/Confirm button, target chips, and deselect clicks.
--- @param self table
--- @param x number
--- @param y number
--- @param ctx table
--- @return boolean handled
function M.on_press(self, x, y, ctx)
	local s = self._state
	local match = ctx.match
	local layout = ctx.layout
	local active = active_player(s, match)
	if not active then
		return false
	end
	local hand_count = #active.cards.hand.ids
	if s.selected_index and s.selected_index > hand_count then
		s.selected_index = nil
	end
	local hand_index = layout_mod.hand_index_at(layout, x, y, hand_count)
	if hand_index then
		if s.hand_target_phase == "armed" then
			if hand_index == s.armed_hand_index then
				return true
			end
			toggle_selected_target(self, {
				object_type = "card",
				owner = match.to_play,
				hand_index = hand_index,
			}, ctx)
			return true
		end
		if s.selected_index == hand_index then
			refresh(self, ctx)
			return true
		end
		s.selected_index = hand_index
		s.selected_targets = {}
		s.popped_target_indices = {}
		s.drag_active = true
		s.drag_mode = "none"
		s.drag_targeting = false
		s.drag_index = hand_index
		s.start_x = x
		s.start_y = y
		s.current_x = x
		s.current_y = y
		s.drag_arrow_from_x = x
		s.drag_arrow_from_y = y
		s.drag_arrow_to_x = x
		s.drag_arrow_to_y = y
		s.drag_target_ref = nil
		s.drag_target_valid = false
		s.drag_target_error = nil
		s.moved = false
		refresh(self, ctx)
		return true
	end
	local use = layout_mod.card_use_button_rect(layout)
	if (s.selected_index or s.hand_target_phase == "armed")
		and x >= use.x
		and x <= use.x + use.w
		and y >= use.y
		and y <= use.y + use.h
	then
		self:try_commit("button", ctx)
		return true
	end
	if not s.selected_index and s.hand_target_phase ~= "armed" then
		return false
	end
	for i = 1, #s.target_chip_rects do
		local chip = s.target_chip_rects[i]
		if x >= chip.x and x <= chip.x + chip.w and y >= chip.y and y <= chip.y + chip.h then
			table.remove(s.selected_targets, i)
			s.status_text = ""
			refresh(self, ctx)
			return true
		end
	end
	if s.hand_target_phase == "armed" then
		return false
	end
	local selected_card_def = current_selected_card(s, active)
	if selected_card_def and selected_card_def.target_object_type == "stone" then
		return false
	end
	s.selected_index = nil
	s.selected_targets = {}
	refresh(self, ctx)
	return true
end

--- Toggles a board stone target when a stone-targeting card flow is active.
--- @param self table
--- @param row integer
--- @param col integer
--- @param ctx table
--- @return boolean handled
function M.on_board_stone(self, row, col, ctx)
	local s = self._state
	if s.hand_target_phase == "armed" then
		return false
	end
	if not s.selected_index then
		return false
	end
	local active = active_player(s, ctx.match)
	local card_id = active and active.cards.hand.ids[s.selected_index] or nil
	local card_def = card_id and content.get_card(card_id) or nil
	if not card_def or card_def.target_object_type ~= "stone" then
		return false
	end
	toggle_selected_target(self, { object_type = "stone", row = row, col = col }, ctx)
	return true
end

--- Updates drag position, drag mode, and arrow targeting preview.
--- @param self table
--- @param x number
--- @param y number
--- @param ctx table
--- @return nil
function M.on_move(self, x, y, ctx)
	local s = self._state
	if not s.drag_active then
		return
	end
	s.current_x = x
	s.current_y = y
	local dx = x - s.start_x
	local dy = y - s.start_y
	if (dx * dx + dy * dy) > DRAG_MOVE_THRESHOLD_SQ then
		s.moved = true
		local active = active_player(s, ctx.match)
		local card_def = current_selected_card(s, active)
		if card_targets_stone(card_def) then
			s.drag_targeting = true
			s.drag_mode = "target_arrow"
		else
			s.drag_mode = "to_confirm"
		end
	end
	update_card_drag_targeting(self, x, y, ctx)
end

--- Ends card drag; may commit via drag-to-confirm or drag-arrow.
--- @param self table
--- @param x number
--- @param y number
--- @param ctx table
--- @return nil
function M.on_release(self, x, y, ctx)
	local s = self._state
	if not s.drag_active then
		return
	end
	if s.moved and s.drag_index then
		if s.drag_mode == "target_arrow" then
			update_card_drag_targeting(self, x, y, ctx)
			self:try_commit("drag_arrow", ctx)
		else
			local use = layout_mod.card_use_button_rect(ctx.layout)
			if x >= use.x and x <= use.x + use.w and y >= use.y and y <= use.y + use.h then
				self:try_commit("drag_confirm", ctx)
			end
		end
	elseif s.drag_index then
		s.selected_index = s.drag_index
		refresh(self, ctx)
	end
	s.drag_active = false
	s.drag_mode = "none"
	s.drag_targeting = false
	s.drag_index = nil
	s.drag_target_ref = nil
	s.drag_target_valid = false
	s.drag_target_error = nil
	s.moved = false
end

return M
