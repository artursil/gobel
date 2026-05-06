--- Unified effect registry: dispatches to objects/ modules.
--- All gameplay effects resolve through this single entry point.
--- @module effect_registry

local objects_effects = require("objects.effects")
local objects_stones = require("objects.stones")
local objects_stances = require("objects.stances")
local objects_cards = require("objects.cards")

local M = {}

--- Stance effects (unified in objects.effects).
M.stances = {}
function M.stances.resolve(stance, state)
	local objects_defs = require("objects.definitions.stances")
	local stance_def = objects_defs[stance.type]
	if not stance_def or not stance_def.effects then
		return {}
	end
	local owner = stance.owner
	if owner ~= "A" and owner ~= "B" then
		owner = (owner == "white" or owner == "B") and "B" or "A"
	end
	local out = {}
	for i = 1, #stance_def.effects do
		local e = stance_def.effects[i]
		local effect_builder = objects_effects[e.effect_name]
		if effect_builder then
			out[#out + 1] = effect_builder(e)
			out[#out].apply = (function(eff)
				local fn = eff.apply
				return function(s)
					fn(s, owner)
				end
			end)(out[#out])
		end
	end
	return out
end

--- Card effects (unified in objects.effects).
M.cards = {}
function M.cards.resolve(card, state)
	local objects_defs = require("objects.definitions.cards")
	local card_def = objects_defs[card.type]
	if not card_def or not card_def.effects then
		return {}
	end
	local owner = card.owner
	if owner ~= "A" and owner ~= "B" then
		owner = (owner == "white" or owner == "B") and "B" or "A"
	end
	local out = {}
	for i = 1, #card_def.effects do
		local e = card_def.effects[i]
		local effect_builder = objects_effects[e.effect_name]
		if effect_builder then
			out[#out + 1] = effect_builder(e)
			out[#out].apply = (function(eff)
				local fn = eff.apply
				return function(s)
					fn(s, owner)
				end
			end)(out[#out])
		end
	end
	return out
end

--- Stone effects (unified in objects.effects).
M.stones = {}
function M.stones.resolve(effect)
	return objects_effects.resolve(effect)
end

function M.stones.resolve_board_stone(stone_cell, row, col, state)
	return objects_effects.resolve_board_stone(stone_cell, row, col, state)
end

return M
