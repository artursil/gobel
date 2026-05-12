--- Stance layout: canonical player-owned slots vs derived resolver walk order.
---
--- **Canonical**: Each side keeps stance ids only under ``state.players.{black|white}.stances`` —
--- ``fixed`` then ``swappable`` (arrays of definition ids). Temporary runtime stances stay in
--- ``state.temporary_stances`` with explicit ``owner``; they do not occupy a fixed/swappable slot.
---
--- **Derived**: ``flatten_stances_for_resolve(state)`` fills ``state._stance_effect_order`` — one array
--- rebuilt whenever effects are collected: black slots in panel order, white slots, then temporary
--- entries. Each row has ``type``, ``owner``, optional ``instance``, ``slot_index`` (1-based within
--- that owner's panel; ``nil`` for temporaries), and ``index`` (global walk index). Effect collection,
--- ``state_queries.source_stance_*``, and blueprint copy-right scan the derived list or canonical
--- per-owner slots — never a standalone ``state.stances`` flat list as source of truth.
---
--- @module single_game.resolver.stance_order

local config = require("config")
local match_state = require("match_state")

local M = {}

--- @param side string "black"|"white"
--- @return "B"|"W"
local function owner_token_for_side(side)
	if side == "white" then
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- Ordered permanent stance slots for one player (fixed then swappable). Panel lane index is ``slot_index``.
--- @param state table
--- @param side string "black"|"white"
--- @return table[] rows ``{ slot_index, type, owner }``
function M.canonical_stance_slots_for_side(state, side)
	local owner = owner_token_for_side(side)
	local player = match_state.player_for_color(state, side)
	local out = {}
	local si = 1
	for _, stance_id in ipairs(player.stances.fixed or {}) do
		out[#out + 1] = { slot_index = si, type = stance_id, owner = owner }
		si = si + 1
	end
	for _, stance_id in ipairs(player.stances.swappable or {}) do
		out[#out + 1] = { slot_index = si, type = stance_id, owner = owner }
		si = si + 1
	end
	return out
end

--- Full effect walk order for one scoring resolve: black rows, white rows, then temporary stances.
--- Sets ``state._stance_effect_order`` and returns it. Each entry: ``type``, ``owner``, ``instance``,
--- ``slot_index`` (nil for temporaries), ``index`` (global 1-based).
--- @param state table
--- @return table
function M.flatten_stances_for_resolve(state)
	local order = {}
	local gi = 1
	for _, side in ipairs({ "black", "white" }) do
		local slots = M.canonical_stance_slots_for_side(state, side)
		for _, s in ipairs(slots) do
			order[gi] = {
				type = s.type,
				owner = s.owner,
				instance = nil,
				slot_index = s.slot_index,
				index = gi,
			}
			gi = gi + 1
		end
	end
	for _, temp in ipairs(state.temporary_stances or {}) do
		local def_id = temp.def_id
		order[gi] = {
			type = def_id,
			owner = temp.owner,
			instance = temp,
			slot_index = nil,
			index = gi,
		}
		gi = gi + 1
	end
	state._stance_effect_order = order
	return order
end

return M
