--- Entry point: menu, LÖVE callbacks, and routing input to game or home.
if os.getenv("DEBUG") then
    require("mobdebug").start()
end
local config = require("config")
local game = require("game")
local home = require("home")
local layout_mod = require("layout")
local match_state = require("match_state")
local render = require("render")
local board = require("board")
local content = require("content")
local resolver = require("resolver")
local ui_fonts = require("ui.fonts")
local stance_detail_popup = require("ui.stance_detail_popup")


local screen
local match
local layout
local hover_row
local hover_col
local popup_state
local stone_drag
local card_ui
local stance_ui
local influence_probe
local menu_step
local dropdown_open
local dropdown_page
local selected_game_type

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

local function reset_menu_state()
	menu_step = "game_type"
	dropdown_open = false
	dropdown_page = 1
	selected_game_type = "standard"
end

local function is_popup_open()
	return popup_state.mode ~= "none"
end

--- @return nil
local function reset_popup()
	popup_state = { mode = "none", stone_id = nil, stones = {}, focus_index = nil, anchor_rect = nil, selected_slot = nil, row = nil, col = nil, owner = nil, game_state = nil, ring_side = nil }
end

--- @return nil
local function close_selector_popup()
	reset_popup()
end

local function open_board_stone_popup(row, col)
	local cell = match.board[row] and match.board[row][col]
	if board.is_empty(cell) then
		return false
	end
	popup_state.mode = "board-stone-info"
	popup_state.stone_id = cell.kind
	popup_state.row = row
	popup_state.col = col
	popup_state.owner = cell.color
	popup_state.game_state = match
	return true
end

--- @param active table
--- @param slot_index integer
--- @return boolean
local function open_selector_popup(active, slot_index)
	local stone_id = active.stones.playable_stones[slot_index]
	if not stone_id then
		return false
	end
	if not game.select_stone(match, stone_id, slot_index) then
		return false
	end
	local rects = layout_mod.stone_chip_rects(layout, #active.stones.playable_stones)
	popup_state.mode = "selector-details"
	popup_state.stone_id = stone_id
	popup_state.anchor_rect = rects[slot_index]
	popup_state.selected_slot = slot_index
	return true
end

--- @param active table
--- @return nil
local function open_pouch_popup(active)
	local ids = active.stones.pouch.ids
	popup_state.mode = "pouch-browser"
	popup_state.stones = {}
	for i = 1, #ids do
		popup_state.stones[i] = ids[i]
	end
	popup_state.focus_index = (#popup_state.stones > 0) and 1 or nil
	popup_state.stone_id = nil
	popup_state.anchor_rect = nil
	popup_state.selected_slot = nil
	popup_state.ring_side = active.side
end

--- @param active table
--- @return nil
local function open_deck_popup(active)
	local ids = active.cards.deck.ids
	popup_state.mode = "deck-browser"
	popup_state.cards = {}
	for i = 1, #ids do
		popup_state.cards[i] = ids[i]
	end
	popup_state.played_cards = {}
	local played = active.cards.discard.ids
	for i = 1, #played do
		popup_state.played_cards[i] = played[i]
	end
	if #popup_state.cards > 0 then
		popup_state.focus_group = "deck"
		popup_state.focus_index = 1
	elseif #popup_state.played_cards > 0 then
		popup_state.focus_group = "played"
		popup_state.focus_index = 1
	else
		popup_state.focus_group = nil
		popup_state.focus_index = nil
	end
	popup_state.stone_id = nil
	popup_state.anchor_rect = nil
	popup_state.selected_slot = nil
end

local function open_discard_popup(active)
	popup_state.mode = "discard-browser"
	popup_state.cards = {}
	popup_state.played_cards = {}
	local discarded = active.cards.discard.ids
	for i = 1, #discarded do
		popup_state.played_cards[i] = discarded[i]
	end
	if #popup_state.played_cards > 0 then
		popup_state.focus_group = "played"
		popup_state.focus_index = 1
	else
		popup_state.focus_group = nil
		popup_state.focus_index = nil
	end
	popup_state.stone_id = nil
	popup_state.anchor_rect = nil
	popup_state.selected_slot = nil
end

--- @param x number
--- @param y number
--- @return boolean
local function handle_score_box_click(x, y)
	if x >= layout.score_player.x and x <= layout.score_player.x + layout.score_player.w and
	   y >= layout.score_player.y and y <= layout.score_player.y + layout.score_player.h then
		render.toggle_score_display_mode()
		return true
	end
	if x >= layout.score_opponent.x and x <= layout.score_opponent.x + layout.score_opponent.w and
	   y >= layout.score_opponent.y and y <= layout.score_opponent.y + layout.score_opponent.h then
		render.toggle_score_display_mode()
		return true
	end
	return false
end

--- @param x number
--- @param y number
--- @param active table
--- @param stone_count integer
--- @return boolean
local function handle_open_popup_click(x, y, active, stone_count)
	if is_popup_open() then
		return false
	end
	local action_rects = layout_mod.player_action_icon_rects(layout)
	local bowl = action_rects[1]
	if x >= bowl.x and x <= bowl.x + bowl.w and y >= bowl.y and y <= bowl.y + bowl.h then
		open_pouch_popup(active)
		return true
	end
	local deck = action_rects[2]
	if x >= deck.x and x <= deck.x + deck.w and y >= deck.y and y <= deck.y + deck.h then
		open_deck_popup(active)
		return true
	end
	local discard = layout_mod.discard_icon_rect(layout)
	if x >= discard.x and x <= discard.x + discard.w and y >= discard.y and y <= discard.y + discard.h then
		open_discard_popup(active)
		return true
	end
	local stone_index = layout_mod.stone_index_at(layout, x, y, stone_count)
	if not stone_index then
		return false
	end
	local stone_id = active.stones.playable_stones[stone_index]
	if stone_id then
		stone_drag.active = true
		stone_drag.stone_id = stone_id
		stone_drag.source_index = stone_index
		stone_drag.start_x = x
		stone_drag.start_y = y
		stone_drag.current_x = x
		stone_drag.current_y = y
		stone_drag.moved = false
	end
	return true
end

--- @param x number
--- @param y number
--- @param active table
--- @param stone_count integer
--- @return boolean
local function handle_active_popup_click(x, y, active, stone_count)
	if popup_state.mode == "selector-details" then
		local stone_index = layout_mod.stone_index_at(layout, x, y, stone_count)
		if not stone_index then
			close_selector_popup()
			return false
		end
		if popup_state.selected_slot ~= stone_index then
			open_selector_popup(active, stone_index)
		end
		return true
	end
	if popup_state.mode == "board-stone-info" then
		local popup_hit = render.popup_hit_test(layout, popup_state, x, y)
		if popup_hit.kind == "consume" then
			return false
		end
		if popup_hit.kind == "none" then
			reset_popup()
			return false
		end
	end
	if not is_popup_open() then
		return false
	end
	local popup_hit = render.popup_hit_test(layout, popup_state, x, y)
	if popup_hit.kind == "close" then
		reset_popup()
		return true
	end
	if popup_hit.kind == "pouch_stone" then
		popup_state.focus_index = popup_hit.index
		return true
	end
	if popup_hit.kind == "deck_card" then
		popup_state.focus_group = popup_hit.group
		popup_state.focus_index = popup_hit.index
		return true
	end
	return true
end

--- @return nil
local function reset_stone_drag()
	stone_drag = {
		active = false,
		stone_id = nil,
		source_index = nil,
		start_x = 0,
		start_y = 0,
		current_x = 0,
		current_y = 0,
		moved = false,
	}
end

--- @return nil
local function reset_card_ui()
	card_ui = {
		selected_index = nil,
		selected_targets = {},
		can_use = false,
		validation_error = nil,
		validation_reason = "",
		requirement_text = "",
		status_text = "",
		selected_target_labels = {},
		target_chip_rects = {},
		invalid_target_feedback = nil,
		card_target_hint_indices = {},
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
	}
end

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

local function current_selected_card(active)
	local idx = card_ui.selected_index
	local card_id = idx and active.cards.hand.ids[idx] or nil
	if not card_id then
		return nil, nil
	end
	return content.get_card(card_id), card_id
end

local function refresh_card_selection_state()
	local active = match and match_state.player_for_color(match, match.to_play) or nil
	if not active then
		return
	end
	match.selected_card_targets = {}
	match.card_target_hint_cells = {}
	card_ui.card_target_hint_indices = {}
	if not card_ui.selected_index then
		card_ui.can_use = false
		card_ui.validation_error = nil
		card_ui.validation_reason = ""
		card_ui.status_text = ""
		card_ui.requirement_text = ""
		card_ui.selected_target_labels = {}
		card_ui.target_chip_rects = {}
		return
	end
	local card_def = current_selected_card(active)
	if not card_def then
		card_ui.selected_index = nil
		card_ui.selected_targets = {}
		card_ui.can_use = false
		card_ui.validation_error = nil
		card_ui.validation_reason = ""
		card_ui.status_text = ""
		card_ui.requirement_text = ""
		card_ui.selected_target_labels = {}
		card_ui.target_chip_rects = {}
		return
	end
	local validation = resolver.validate_card_targets(card_def, card_ui.selected_targets, match, match.to_play)
	card_ui.can_use = validation.ok
	card_ui.validation_error = validation.error
	card_ui.validation_reason = validation.ok and "" or map_validation_reason(validation.error)
	local min_targets = card_def.min_targets or (card_def.play_mode == "target_single" and 1 or 0)
	local max_targets = card_def.max_targets or min_targets
	if card_def.play_mode == "instant" or card_def.play_mode == nil then
		card_ui.requirement_text = "No target required"
	else
		local requirement_suffix = ""
		if min_targets == max_targets then
			requirement_suffix = string.format(" (need exactly %d)", max_targets)
		elseif min_targets > 0 then
			requirement_suffix = string.format(" (min %d)", min_targets)
		end
		card_ui.requirement_text = string.format("Targets: %d/%d%s", #card_ui.selected_targets, max_targets, requirement_suffix)
	end
	card_ui.selected_target_labels = {}
	for i = 1, #card_ui.selected_targets do
		card_ui.selected_target_labels[i] = target_display_label(card_ui.selected_targets[i])
	end
	card_ui.target_chip_rects = layout_mod.card_target_chip_rects(layout, #card_ui.selected_targets)
	match.selected_card_targets = card_ui.selected_targets
	for i = 1, #card_ui.selected_targets do
		local ref = card_ui.selected_targets[i]
		if ref.object_type == "stone" then
			match.card_target_hint_cells[target_key(ref)] = true
		elseif ref.object_type == "card" and ref.owner == match.to_play then
			card_ui.card_target_hint_indices[ref.hand_index] = true
		end
	end
end

local function flash_invalid_target(ref, message)
	card_ui.status_text = message or ""
	card_ui.invalid_target_feedback = {
		key = target_key(ref),
		object_type = ref.object_type,
		row = ref.row,
		col = ref.col,
		hand_index = ref.hand_index,
		remaining = 0.55,
	}
end

local function toggle_selected_target(ref)
	local key = target_key(ref)
	for i = 1, #card_ui.selected_targets do
		if target_key(card_ui.selected_targets[i]) == key then
			table.remove(card_ui.selected_targets, i)
			card_ui.status_text = ""
			refresh_card_selection_state()
			return
		end
	end
	local active = match_state.player_for_color(match, match.to_play)
	local card_def = current_selected_card(active)
	if not card_def then
		return
	end
	local candidate_validation =
		resolver.validate_card_target_candidate(card_def, card_ui.selected_targets, ref, match, match.to_play)
	if not candidate_validation.ok then
		flash_invalid_target(ref, map_validation_reason(candidate_validation.error))
		refresh_card_selection_state()
		return
	end
	card_ui.selected_targets[#card_ui.selected_targets + 1] = ref
	card_ui.status_text = ""
	refresh_card_selection_state()
end

local function card_is_targetable(card_def)
	return card_def and card_def.play_mode and card_def.play_mode ~= "instant" and card_def.target_object_type ~= nil
end

local function copy_targets(targets)
	local out = {}
	for i = 1, #targets do
		out[i] = targets[i]
	end
	return out
end

local function build_drag_candidate_target(x, y, active, card_def)
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

local function update_card_drag_targeting(x, y, active)
	if not card_ui.drag_active or not card_ui.drag_targeting then
		return
	end
	local slots = layout_mod.hand_fan_slots(layout, #active.cards.hand.ids)
	local drag_slot = slots[card_ui.drag_index]
	if drag_slot then
		card_ui.drag_arrow_from_x = drag_slot.x + drag_slot.w * 0.5
		card_ui.drag_arrow_from_y = drag_slot.y + drag_slot.h * 0.5
	else
		card_ui.drag_arrow_from_x = card_ui.start_x
		card_ui.drag_arrow_from_y = card_ui.start_y
	end
	local card_def = current_selected_card(active)
	local candidate, tx, ty = build_drag_candidate_target(x, y, active, card_def)
	card_ui.drag_arrow_to_x = tx
	card_ui.drag_arrow_to_y = ty
	card_ui.drag_target_ref = nil
	card_ui.drag_target_valid = false
	card_ui.drag_target_error = nil
	if not candidate then
		return
	end
	local candidate_targets = copy_targets(card_ui.selected_targets)
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
	card_ui.drag_target_ref = candidate
	card_ui.drag_target_valid = validation.ok
	card_ui.drag_target_error = validation.error
end

local function reset_stance_ui()
	stance_ui = {
		owner_key = nil,
		index = nil,
		drag_active = false,
		drag_index = nil,
		drag_was_selected = false,
		start_x = 0,
		start_y = 0,
		current_x = 0,
		current_y = 0,
		moved = false,
	}
end

local function reset_influence_probe()
	influence_probe = nil
end

local function update_influence_probe(dt)
	if not influence_probe then
		return
	end
	influence_probe.remaining = (influence_probe.remaining or 0) - dt
	if influence_probe.remaining <= 0 then
		reset_influence_probe()
	end
end

local function clear_influence_probe_on_board_click(x, y)
	local row, col = layout_mod.pixel_to_grid(layout, x, y)
	if not row or not col then
		return false
	end
	reset_influence_probe()
	return true
end

local function handle_influence_probe_click(x, y)
	if screen ~= "play" or not match then
		return false
	end
	local row, col = layout_mod.pixel_to_grid(layout, x, y)
	if not row or not col then
		reset_influence_probe()
		return true
	end
	local cell = match.board[row] and match.board[row][col]
	if not cell or not board.is_empty(cell) then
		reset_influence_probe()
		return true
	end
	local by_row = match.territory_decision_sources and match.territory_decision_sources[row]
	local source = by_row and by_row[col] or nil
	if not source or not source.contributors then
		reset_influence_probe()
		return true
	end
	influence_probe = {
		row = row,
		col = col,
		owner = source.owner,
		contributors = source.contributors,
		remaining = 3,
	}
	return true
end

local function owner_color_from_key(owner_key)
	if owner_key == config.OWNER_BLACK then
		return "black"
	end
	return "white"
end

local function swap_stance_positions(owner_key, from_index, to_index)
	if not from_index or not to_index or from_index == to_index then
		return
	end
	local player = match_state.player_for_color(match, owner_color_from_key(owner_key))
	local fixed_count = #player.stances.fixed
	local base_count = fixed_count + #player.stances.swappable
	if from_index > base_count or to_index > base_count then
		return
	end
	local combined = {}
	for i = 1, fixed_count do
		combined[#combined + 1] = player.stances.fixed[i]
	end
	for i = 1, #player.stances.swappable do
		combined[#combined + 1] = player.stances.swappable[i]
	end
	combined[from_index], combined[to_index] = combined[to_index], combined[from_index]
	for i = 1, fixed_count do
		player.stances.fixed[i] = combined[i]
	end
	for i = fixed_count + 1, #combined do
		player.stances.swappable[i - fixed_count] = combined[i]
	end
end

local function begin_stance_drag(x, y)
	local hit = render.stance_hit_test(match, layout, x, y)
	if hit.kind == "stance_card" then
		stance_ui.drag_active = true
		stance_ui.drag_index = hit.index
		stance_ui.owner_key = hit.owner_key
		stance_ui.start_x = x
		stance_ui.start_y = y
		stance_ui.current_x = x
		stance_ui.current_y = y
		stance_ui.moved = false
		stance_ui.drag_was_selected = (stance_ui.owner_key == hit.owner_key and stance_ui.index == hit.index)
		return true
	end
	if stance_ui.index and hit.kind == "none" then
		local popup_rect = render.get_stance_detail_popup_rect(match, layout, stance_ui)
		if stance_detail_popup.contains(popup_rect, x, y) then
			return true
		end
		reset_stance_ui()
		return false
	end
	return hit.kind == "stance_panel"
end

local function end_stance_drag(x, y)
	if not stance_ui.drag_active then
		return false
	end
	local owner_key = stance_ui.owner_key
	local drag_index = stance_ui.drag_index
	local moved = stance_ui.moved
	stance_ui.drag_active = false
	stance_ui.drag_index = nil
	stance_ui.moved = false
	if moved then
		local hit = render.stance_hit_test(match, layout, x, y)
		if hit.kind == "stance_card" and hit.owner_key == owner_key then
			swap_stance_positions(owner_key, drag_index, hit.index)
		end
		return true
	end
	if stance_ui.owner_key == owner_key and stance_ui.index == drag_index then
		reset_stance_ui()
	else
		stance_ui.owner_key = owner_key
		stance_ui.index = drag_index
	end
	return true
end

--- @param x number
--- @param y number
--- @param active table
--- @return boolean
local function handle_card_press(x, y, active)
	if popup_state.mode == "selector-details" then
		close_selector_popup()
	end
	local hand_count = #active.cards.hand.ids
	if card_ui.selected_index and card_ui.selected_index > hand_count then
		card_ui.selected_index = nil
	end
	local hand_index = layout_mod.hand_index_at(layout, x, y, hand_count)
	if hand_index then
		local selected_card_def = current_selected_card(active)
		if
			card_ui.selected_index
			and selected_card_def
			and selected_card_def.target_object_type == "card"
			and hand_index ~= card_ui.selected_index
		then
			toggle_selected_target({
				object_type = "card",
				owner = match.to_play,
				hand_index = hand_index,
			})
			return true
		end
		card_ui.selected_index = hand_index
		card_ui.selected_targets = {}
		card_ui.drag_active = true
		card_ui.drag_targeting = false
		card_ui.drag_index = hand_index
		card_ui.start_x = x
		card_ui.start_y = y
		card_ui.current_x = x
		card_ui.current_y = y
		card_ui.drag_arrow_from_x = x
		card_ui.drag_arrow_from_y = y
		card_ui.drag_arrow_to_x = x
		card_ui.drag_arrow_to_y = y
		card_ui.drag_target_ref = nil
		card_ui.drag_target_valid = false
		card_ui.drag_target_error = nil
		card_ui.moved = false
		refresh_card_selection_state()
		local card_def = current_selected_card(active)
		if card_def and (card_def.play_mode == "instant" or card_def.play_mode == nil) and card_ui.can_use then
			local ok = game.play_card(match, card_ui.selected_index, card_ui.selected_targets)
			if ok then
				card_ui.selected_index = nil
				card_ui.selected_targets = {}
				refresh_card_selection_state()
			end
		end
		return true
	end
	if not card_ui.selected_index then
		return false
	end
	for i = 1, #card_ui.target_chip_rects do
		local chip = card_ui.target_chip_rects[i]
		if x >= chip.x and x <= chip.x + chip.w and y >= chip.y and y <= chip.y + chip.h then
			table.remove(card_ui.selected_targets, i)
			card_ui.status_text = ""
			refresh_card_selection_state()
			return true
		end
	end
	local use = layout_mod.card_use_button_rect(layout)
	if x >= use.x and x <= use.x + use.w and y >= use.y and y <= use.y + use.h then
		if not card_ui.can_use then
			return true
		end
		local ok = game.play_card(match, card_ui.selected_index, card_ui.selected_targets)
		if ok then
			card_ui.selected_index = nil
			card_ui.selected_targets = {}
			refresh_card_selection_state()
		end
		return true
	end
	local selected_card_def = current_selected_card(active)
	if selected_card_def and selected_card_def.target_object_type == "stone" then
		return false
	end
	card_ui.selected_index = nil
	card_ui.selected_targets = {}
	refresh_card_selection_state()
	return true
end

--- @param x number
--- @param y number
--- @return nil
local function handle_board_press(x, y)
	local row, col = layout_mod.pixel_to_grid(layout, x, y)
	if not row then
		return
	end
	local cell = match.board[row] and match.board[row][col]
	if cell and not board.is_empty(cell) then
		match.selected_card_target = {
			row = row,
			col = col,
			stone_id = cell.kind,
			stone_color = cell.color,
		}
		local active = match_state.player_for_color(match, match.to_play)
		local selected_index = card_ui.selected_index
		local card_id = selected_index and active.cards.hand.ids[selected_index] or nil
		local card_def = card_id and content.get_card(card_id) or nil
		if card_def and card_def.target_object_type == "stone" then
			toggle_selected_target({
				object_type = "stone",
				row = row,
				col = col,
			})
		end
		open_board_stone_popup(row, col)
		return
	end
	game.player_move(match, row, col)
end

--- @return nil
local function reset_to_menu()
	screen = "menu"
	match = nil
	reset_menu_state()
	hover_row, hover_col = nil, nil
	reset_popup()
	reset_stone_drag()
	reset_card_ui()
	reset_stance_ui()
	reset_influence_probe()
end

--- Seeds RNG, fonts, and opens the home screen.
function love.load()
	ui_fonts.init()
	ui_fonts.apply_default()
	local w, h = love.graphics.getDimensions()
	layout = layout_mod.from_window(w, h)
	screen = "menu"
	match = nil
	reset_menu_state()
	hover_row, hover_col = nil, nil
	reset_popup()
	reset_stone_drag()
	reset_card_ui()
	reset_stance_ui()
	reset_influence_probe()
	love.math.setRandomSeed(love.timer.getTime() * 1000000 + os.time())
	require("ui.graphics_diagnostics").report_startup()
end

--- Resizes board layout when the window changes during play.
--- @param w number
--- @param h number
function love.resize(w, h)
	if screen == "play" then
		layout = layout_mod.from_window(w, h)
	end
end

--- Advances the bot when in a player-vs-bot match.
--- @param dt number
function love.update(dt)
	if screen == "play" and match then
		if card_ui and card_ui.invalid_target_feedback then
			card_ui.invalid_target_feedback.remaining = card_ui.invalid_target_feedback.remaining - dt
			if card_ui.invalid_target_feedback.remaining <= 0 then
				card_ui.invalid_target_feedback = nil
			end
		end
		update_influence_probe(dt)
		render.update(dt, match, layout)
		if not render.is_score_animating() then
			game.tick_ai(match, dt)
		end
	end
end

--- Draws either the home screen or the active match.
function love.draw()
	local w, h = love.graphics.getDimensions()
	if screen == "menu" then
		if menu_step == "game_type" then
			home.draw_game_type_menu(w, h, dropdown_open, selected_game_type, dropdown_page)
		else
			home.draw_match_menu(w, h, selected_game_type)
		end
		return
	end
	local hr, hc = hover_row, hover_col
	local show_hover = game.is_human_turn(match)
	render.set_card_ui_state(card_ui)
	render.set_stance_ui_state(stance_ui)
	render.set_stone_drag_state(stone_drag)
	render.set_influence_probe_state(influence_probe)
	render.draw(match, layout, hr, hc, show_hover, popup_state, stone_drag)
end

--- Routes clicks to menu buttons or board placement.
--- @param x number
--- @param y number
--- @param button integer
function love.mousepressed(x, y, button)
	if button == 2 then
		clear_influence_probe_on_board_click(x, y)
		handle_influence_probe_click(x, y)
		return
	end
	if button ~= 1 then
		return
	end
	local w, h = love.graphics.getDimensions()
	if screen == "menu" then
		if menu_step == "game_type" then
			local pick = home.hit_test_game_type(x, y, w, h, dropdown_open, selected_game_type, dropdown_page)
			if pick == "dropdown_open" then
				dropdown_open = true
				dropdown_page = home.game_type_page_for_selection(selected_game_type)
				return
			elseif pick == "dropdown_close" then
				dropdown_open = false
				dropdown_page = home.game_type_page_for_selection(selected_game_type)
				return
			elseif pick == "dropdown_prev_page" then
				dropdown_page = math.max(1, (dropdown_page or 1) - 1)
				return
			elseif pick == "dropdown_next_page" then
				dropdown_page = (dropdown_page or 1) + 1
				return
			elseif pick == "dropdown_noop" then
				return
			elseif pick and pick:sub(1, 10) == "game_type:" then
				selected_game_type = pick:sub(11)
				dropdown_open = false
				dropdown_page = home.game_type_page_for_selection(selected_game_type)
				menu_step = "match"
				return
			end
		elseif menu_step == "match" then
			local pick = home.hit_test_match(x, y, w, h)
			if pick == "pvp" or pick == "pvc" then
				match = game.new(pick, selected_game_type, "regional")
				screen = "play"
				layout = layout_mod.from_window(w, h)
				reset_popup()
				reset_stone_drag()
				reset_card_ui()
				reset_stance_ui()
				reset_influence_probe()
			end
			return
		end
		return
	end
	if match.over then
		return
	end
	clear_influence_probe_on_board_click(x, y)
	if stone_drag.active then
		return
	end
	if stance_ui.drag_active then
		return
	end
	local active = match_state.player_for_color(match, match.to_play)
	local stone_count = #active.stones.playable_stones
	if handle_score_box_click(x, y) then
		return
	end
	if begin_stance_drag(x, y) then
		return
	end
	if handle_active_popup_click(x, y, active, stone_count) then
		return
	end
	if handle_open_popup_click(x, y, active, stone_count) then
		return
	end
	if handle_card_press(x, y, active) then
		return
	end
	handle_board_press(x, y)
end

--- Tracks hover for the placement preview on the board only.
--- @param x number
--- @param y number
function love.mousemoved(x, y)
	if screen ~= "play" then
		hover_row, hover_col = nil, nil
		return
	end
	if stone_drag.active then
		stone_drag.current_x = x
		stone_drag.current_y = y
		local dx = x - stone_drag.start_x
		local dy = y - stone_drag.start_y
		if (dx * dx + dy * dy) > 64 then
			stone_drag.moved = true
			if popup_state.mode == "selector-details" then
				close_selector_popup()
			end
		end
	end
	if stance_ui.drag_active then
		stance_ui.current_x = x
		stance_ui.current_y = y
		local dx = x - stance_ui.start_x
		local dy = y - stance_ui.start_y
		if (dx * dx + dy * dy) > 64 then
			stance_ui.moved = true
		end
	end
	if card_ui.drag_active then
		card_ui.current_x = x
		card_ui.current_y = y
		local dx = x - card_ui.start_x
		local dy = y - card_ui.start_y
		if (dx * dx + dy * dy) > 64 then
			card_ui.moved = true
			local active = match_state.player_for_color(match, match.to_play)
			local card_def = current_selected_card(active)
			if card_is_targetable(card_def) then
				card_ui.drag_targeting = true
			end
		end
		local active = match_state.player_for_color(match, match.to_play)
		update_card_drag_targeting(x, y, active)
	end
	hover_row, hover_col = layout_mod.pixel_to_grid(layout, x, y)
end

function love.mousereleased(x, y, button)
	if button ~= 1 or screen ~= "play" or not match then
		return
	end
	if stone_drag.active then
		local active = match_state.player_for_color(match, match.to_play)
		local stone_count = #active.stones.playable_stones
		local source_index = stone_drag.source_index
		local stone_id = stone_drag.stone_id
		if stone_drag.moved then
			if stone_id then
				game.select_stone(match, stone_id, source_index)
			end
			local r, c = layout_mod.pixel_to_grid(layout, x, y)
			if r and c then
				game.player_move(match, r, c)
			end
			reset_stone_drag()
			return
		end
		if source_index and source_index <= stone_count and stone_id then
			open_selector_popup(active, source_index)
		end
		reset_stone_drag()
		return
	end
	if end_stance_drag(x, y) then
		return
	end
	if card_ui.drag_active then
		if card_ui.moved and card_ui.drag_index then
			local active = match_state.player_for_color(match, match.to_play)
			local card_def = current_selected_card(active)
			if card_ui.drag_targeting and card_is_targetable(card_def) then
				update_card_drag_targeting(x, y, active)
				if card_ui.drag_target_ref and card_ui.drag_target_valid then
					local final_targets = copy_targets(card_ui.selected_targets)
					local key = target_key(card_ui.drag_target_ref)
					local duplicate = false
					for i = 1, #final_targets do
						if target_key(final_targets[i]) == key then
							duplicate = true
							break
						end
					end
					if not duplicate then
						final_targets[#final_targets + 1] = card_ui.drag_target_ref
					end
					local ok = game.play_card(match, card_ui.drag_index, final_targets)
					if ok then
						card_ui.selected_index = nil
						card_ui.selected_targets = {}
						card_ui.status_text = ""
						refresh_card_selection_state()
					end
				end
			else
				local use = layout_mod.card_use_button_rect(layout)
				if x >= use.x and x <= use.x + use.w and y >= use.y and y <= use.y + use.h then
					if not card_ui.can_use then
						card_ui.drag_active = false
						card_ui.drag_targeting = false
						card_ui.drag_index = nil
						card_ui.moved = false
						return
					end
					local ok = game.play_card(match, card_ui.drag_index, card_ui.selected_targets)
					if ok then
						card_ui.selected_index = nil
						card_ui.selected_targets = {}
						refresh_card_selection_state()
					end
				end
			end
		elseif card_ui.drag_index then
			card_ui.selected_index = card_ui.drag_index
			refresh_card_selection_state()
		end
		card_ui.drag_active = false
		card_ui.drag_targeting = false
		card_ui.drag_index = nil
		card_ui.drag_target_ref = nil
		card_ui.drag_target_valid = false
		card_ui.drag_target_error = nil
		card_ui.moved = false
	end
end

function love.wheelmoved(x, y)
	if screen ~= "menu" or menu_step ~= "game_type" or not dropdown_open then
		return
	end
	local mx, my = love.mouse.getPosition()
	local w, h = love.graphics.getDimensions()
	local rect = home.game_type_dropdown_scroll_rect(w, h, dropdown_page)
	local inside = mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h
	if not inside then
		return
	end
	if y > 0 then
		dropdown_page = home.step_game_type_page(dropdown_page, -1)
	elseif y < 0 then
		dropdown_page = home.step_game_type_page(dropdown_page, 1)
	end
end

--- Escape toggles menu vs quit; P pass; R restart same mode; M opens menu from play.
--- @param key love.KeyConstant
function love.keypressed(key)
	local w, h = love.graphics.getDimensions()
	if is_popup_open() and key == "escape" then
		reset_popup()
		return
	end
	if key == "escape" then
		if screen == "menu" then
			if menu_step == "match" then
				menu_step = "territory"
			else
				love.event.quit()
			end
		else
			reset_to_menu()
		end
		return
	end
	if screen == "menu" then
		return
	end
	if is_popup_open() then
		return
	end
	if key == "m" then
		reset_to_menu()
		return
	end
	if key == "r" and match then
		local kind = match.match_kind
		match = game.new(kind, match.territory_mode)
		layout = layout_mod.from_window(w, h)
		reset_popup()
		reset_stone_drag()
		reset_card_ui()
		reset_stance_ui()
		reset_influence_probe()
		return
	end
	if key == "p" and match then
		game.player_pass(match)
		return
	end
	if match and key >= "1" and key <= "5" then
		game.play_card(match, tonumber(key))
	end
end
