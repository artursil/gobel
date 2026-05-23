--- Unified effect registry: dispatches to objects/ modules.
--- All gameplay effects resolve through this single entry point.
--- @module effect_registry

local config = require("config")
local objects_effects = require("objects.effects")
local objects_stones = require("objects.stones")
local objects_stances = require("objects.stances")
local objects_cards = require("objects.cards")

local M = {}

local function normalize_owner(owner)
	local ob, ow = config.OWNER_BLACK, config.OWNER_WHITE
	if owner == ob or owner == ow then
		return owner
	end
	return ((owner == "white" or owner == ow) and ow) or ob
end

local function wrap_effect_with_owner(effect_payload, owner)
	effect_payload.owner = owner
	effect_payload.apply = (function(eff)
		local fn = eff.apply
		return function(s)
			fn(s, owner)
		end
	end)(effect_payload)
	return effect_payload
end

local function append_wrapped_effects(out, effects, owner, selected_target)
	for i = 1, #effects do
		local wrapped = wrap_effect_with_owner(effects[i], owner)
		wrapped._effect_def = effects[i]._effect_def
		wrapped.macro = effects[i].macro
		wrapped.sub = effects[i].sub
		wrapped.meta = wrapped.meta or {}
		wrapped.meta.selected_target = selected_target
		out[#out + 1] = wrapped
	end
end

--- Stance effects (unified in objects.effects).
M.stances = {}
function M.stances.resolve(stance, state)
	local owner = normalize_owner(stance.owner)
	local out = {}
	local resolved = objects_effects.resolve_stance_definition_effects(stance.type)
	append_wrapped_effects(out, resolved, owner, nil)
	return out
end

--- Card effects (unified in objects.effects).
M.cards = {}
function M.cards.resolve(card, state)
	local owner = normalize_owner(card.owner)
	local out = {}
	local resolved = objects_effects.resolve_card_effects(card)
	append_wrapped_effects(out, resolved, owner, card.selected_target)
	return out
end

--- Stone effects (unified in objects.effects).
M.stones = {}
function M.stones.resolve(effect)
	return objects_effects.resolve(effect)
end

function M.stones.resolve_board_stone(stone_cell, row, col, state, active_macro, active_sub, territory_step)
	return objects_effects.resolve_board_stone(stone_cell, row, col, state, active_macro, active_sub, territory_step)
end

return M
