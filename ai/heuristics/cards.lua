--- Heuristic card play scoring (no resolve_round).
--- @module ai.heuristics.cards

local content = require("content")
local deck = require("deck")
local energy = require("energy")
local synergy = require("ai.heuristics.synergy")

local M = {}

local CARD_OVERRIDES = {}

--- @param card_id string
--- @param fn fun(view: table, hand_index: integer, card_def: table): number
--- @return nil
function M.register(card_id, fn)
	CARD_OVERRIDES[card_id] = fn
end

--- @param card_def table
--- @return number
local function base_value_from_effects(card_def)
	local score = 0
	local effects = card_def.effects or {}
	for i = 1, #effects do
		local eff = effects[i]
		if eff.effect_name == "add_points" and type(eff.value) == "number" then
			score = score + eff.value
		elseif eff.effect_name == "add_mult" and type(eff.value) == "number" then
			score = score + eff.value * 3
		end
	end
	return score
end

--- @param view table
--- @param hand_index integer
--- @return number
function M.score(view, hand_index)
	local cards_state = view:player().cards
	if not deck.can_play_from_hand(cards_state, hand_index) then
		return 0
	end
	local card_id = cards_state.hand.ids[hand_index]
	local card_def = content.get_card(card_id)
	if not card_def then
		return 0
	end
	if not energy.can_spend(view:player(), card_def.energy_cost or 0) then
		return 0
	end
	local override = CARD_OVERRIDES[card_id]
	if override then
		return override(view, hand_index, card_def)
	end
	local score = base_value_from_effects(card_def)
	score = score - (card_def.energy_cost or 0)
	if synergy.count_steel_in_hand(view) > 0 and synergy.has_stance(view, "stance_gluttony") then
		score = score + 1
	end
	return score
end

return M
