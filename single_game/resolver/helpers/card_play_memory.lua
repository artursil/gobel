--- Stages card plays for the resolver and records match history.
---
--- **state.just_played** (array, game state on the match): entries that trigger card effects
--- for the *current* `resolve_round.resolve` pass only. Populated in `PLAY_CARD_COMMIT` after
--- energy spend and hand→discard. Cleared at the end of each full resolve after being copied
--- to history. Shapes like legacy modifier rows: `{ type = card_id, owner, selected_target?, selected_targets? }`
--- so `effect_registry.cards.resolve` and `objects.effects.resolve_card_effects` stay unchanged.
---
--- **state.played_cards** (array, same state): append-only audit trail `{ owner, card_id,
--- selected_target?, selected_targets?, turn_number? }`. Not consulted when collecting effects unless a future
--- effect definition explicitly reads this list.
--- @module single_game.resolver.helpers.card_play_memory

local M = {}

--- Appends one resolved card play to `state.just_played` for the upcoming scoring resolve.
--- @param state table
--- @param entry table must include `type` (card id), `owner` (B/W), optional `selected_target`
--- @return nil
function M.record_just_played_card(state, entry)
	state.just_played = state.just_played or {}
	state.just_played[#state.just_played + 1] = entry
end

--- Moves every entry from `just_played` onto `played_cards` with `turn_number`, then clears `just_played`.
--- @param state table
--- @return nil
function M.flush_just_played_to_history(state)
	state.played_cards = state.played_cards or {}
	state.just_played = state.just_played or {}
	local turn = state.turn_number or 0
	for i = 1, #state.just_played do
		local e = state.just_played[i]
		state.played_cards[#state.played_cards + 1] = {
			owner = e.owner,
			card_id = e.type,
			selected_target = e.selected_target,
			selected_targets = e.selected_targets,
			turn_number = turn,
		}
	end
	state.just_played = {}
end

return M
