--- Canonical action/phase vocabulary for effect scheduling.
--- @module objects.effect_enums

local M = {}

M.ACTION = {
	game_start = "game_start",
	before_turn = "before_turn",
	on_card = "on_card",
	on_play = "on_play",
	end_of_turn = "end_of_turn",
	tick = "tick",
	on_removed = "on_removed",
	game_end = "game_end",
}

M.PHASE = {
	territory = "territory",
	points = "points",
	mult = "mult",
}

M.PHASE_ORDER = { M.PHASE.territory, M.PHASE.points, M.PHASE.mult }

M.ACTION_ORDER = {
	M.ACTION.game_start,
	M.ACTION.before_turn,
	M.ACTION.on_card,
	M.ACTION.on_play,
	M.ACTION.end_of_turn,
	M.ACTION.on_removed,
	M.ACTION.game_end,
}

--- Legacy action names accepted during migration (not in canonical ACTION enum).
M.LEGACY_ACTION = {
	playing_stones = M.ACTION.on_play,
	playing_cards = M.ACTION.on_card,
	board_reconcile = "board_reconcile",
}

local VALID_CANONICAL_ACTION = {}
for _, value in pairs(M.ACTION) do
	VALID_CANONICAL_ACTION[value] = true
end

local VALID_PHASE = {}
for _, value in pairs(M.PHASE) do
	VALID_PHASE[value] = true
end

--- @param action string|nil
--- @return string|nil canonical action or legacy-only name (e.g. board_reconcile)
function M.normalize_action(action)
	if not action then
		return nil
	end
	if VALID_CANONICAL_ACTION[action] then
		return action
	end
	local mapped = M.LEGACY_ACTION[action]
	if mapped then
		return mapped
	end
	return action
end

--- @param macro string|nil
--- @return string|nil
function M.macro_to_action(macro)
	return M.normalize_action(macro)
end

--- @param when string|nil
--- @return string|nil
function M.when_to_action(when)
	return M.normalize_action(when)
end

--- @param sub string|nil
--- @return string|nil phase
function M.sub_to_phase(sub)
	if not sub then
		return nil
	end
	if sub == "distance" then
		return M.PHASE.territory
	end
	if VALID_PHASE[sub] then
		return sub
	end
	return sub
end

--- @param action string|nil
--- @return boolean
function M.is_valid_action(action)
	if not action then
		return false
	end
	if VALID_CANONICAL_ACTION[action] then
		return true
	end
	return M.LEGACY_ACTION[action] ~= nil
end

--- @param phase string|nil
--- @return boolean
function M.is_valid_phase(phase)
	return phase ~= nil and VALID_PHASE[phase] == true
end

--- Resolve-pass callers may still use legacy macro strings; map canonical action back when needed.
--- @param action string
--- @return string
function M.action_to_resolve_macro(action)
	local normalized = M.normalize_action(action)
	if normalized == M.ACTION.on_play then
		return "playing_stones"
	end
	if normalized == M.ACTION.on_card then
		return "playing_cards"
	end
	return normalized or action
end

--- @param resolve_macro string
--- @return string
function M.resolve_macro_to_action(resolve_macro)
	return M.normalize_action(resolve_macro) or resolve_macro
end

return M
