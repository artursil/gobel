--- Legal MAIN-phase turn scripts (card skip / play variants).
--- @module ai.turn.scripts

local content = require("content")
local deck = require("deck")
local energy = require("energy")
local stone_select = require("ai.heuristics.stone_select")
local targets = require("ai.heuristics.targets")

local M = {}

--- @param view table
--- @param type string
--- @param payload table|nil
--- @return table
local function make_action(view, type, payload)
	return {
		actor = view:actor(),
		type = type,
		payload = payload or {},
	}
end

--- @param view table
--- @return table[]
local function stone_steps_if_needed(view)
	local playable = view:playable_stones()
	if #playable == 0 then
		return {}
	end
	local idx = stone_select.choose_index(view)
	local stone_id = playable[idx]
	if view:selected_stone_index() == idx and view:selected_stone_id() == stone_id then
		return {}
	end
	return {
		make_action(view, "SELECT_STONE", {
			stone_id = stone_id,
			stone_index = idx,
		}),
	}
end

--- @param view table
--- @param hand_index integer
--- @return boolean
local function can_play_hand_index(view, hand_index)
	local cards_state = view:player().cards
	if not deck.can_play_from_hand(cards_state, hand_index) then
		return false
	end
	local card_id = cards_state.hand.ids[hand_index]
	local card_def = content.get_card(card_id)
	if not card_def then
		return false
	end
	return energy.can_spend(view:player(), card_def.energy_cost or 0)
end

--- @param view table
--- @return table
local function build_skip_script(view)
	local steps = stone_steps_if_needed(view)
	return {
		script_id = "skip_card",
		hand_index = nil,
		target = nil,
		steps = steps,
	}
end

--- @param view table
--- @param hand_index integer
--- @param row integer|nil
--- @param col integer|nil
--- @return table
local function build_play_script(view, hand_index, row, col)
	local steps = {}
	if row and col then
		steps[#steps + 1] = make_action(view, "SELECT_BOARD_TARGET", { row = row, col = col })
	end
	steps[#steps + 1] = make_action(view, "PLAY_CARD", { hand_index = hand_index })
	local stone_steps = stone_steps_if_needed(view)
	for i = 1, #stone_steps do
		steps[#steps + 1] = stone_steps[i]
	end
	local script_id = "play_card:" .. tostring(hand_index)
	if row and col then
		script_id = script_id .. ":" .. row .. "," .. col
	end
	return {
		script_id = script_id,
		hand_index = hand_index,
		target = row and { row = row, col = col } or nil,
		steps = steps,
	}
end

--- @param view table
--- @param max_scripts integer
--- @return table[]
function M.enumerate(view, max_scripts)
	max_scripts = max_scripts or 12
	local out = { build_skip_script(view) }
	local hand = view:hand_card_ids()
	for hand_index = 1, #hand do
		if can_play_hand_index(view, hand_index) then
			local card_def = content.get_card(hand[hand_index])
			local needs_target = card_def
				and card_def.targeting
				and card_def.targeting.kind == "board_stone"
			if needs_target then
				local cells = targets.legal_for_card(view, hand_index)
				for i = 1, #cells do
					out[#out + 1] = build_play_script(view, hand_index, cells[i].row, cells[i].col)
					if #out >= max_scripts then
						return out
					end
				end
			else
				out[#out + 1] = build_play_script(view, hand_index, nil, nil)
				if #out >= max_scripts then
					return out
				end
			end
		end
	end
	return out
end

return M
