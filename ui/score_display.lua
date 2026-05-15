--- Authoritative scores live on ``state.players`` / ``state.scores`` after ``resolve_round.resolve``.
--- This module holds **presented** score rows only while a ``display_update_*`` rollout is active:
--- HUD reads ``effective_row`` so stepped fields replay from a pre-resolve baseline toward intent ``value``
--- targets without mutating gameplay state.
---
--- **Responsibility**
---
--- | Function / table | Role |
--- | --- | --- |
--- | ``snapshot_scores`` | Shallow numeric copy of both players' ``score`` slices (B/W keys). |
--- | ``after_resolve`` | If any ``display_update_*`` intents exist, merge baseline vs authoritative per field and set ``state._score_display_rollout``; else no-op. |
--- | ``effective_row`` | Row used by ``render`` for one side during rollout or live ``player.score``. |
--- | ``calculate_display_total`` | Same total formula as ``draw_score_box_*`` / ``sync_player_scores`` (ceil on territory, points, plus_mult). |
--- | ``end_rollout`` | Clears rollout; render uses authoritative again. |
--- | ``is_rollout_active`` | True while ``state._score_display_rollout`` is set. |
---
--- **Intent schema** (plain tables on ``state.ui_animation_events``; visual-only, no resolver mutation):
---
--- | Field | Type | Required |
--- | --- | --- | --- |
--- | ``type`` | ``"display_update_territory"`` \| ``"display_update_points"`` \| ``"display_update_plus_mult"`` \| ``"display_update_x_mult"`` | yes |
--- | ``owner`` | ``config.OWNER_BLACK`` (``"B"``) \| ``config.OWNER_WHITE`` (``"W"``) | yes |
--- | ``value`` | number — value to show after this step (Option A) | yes |
--- | ``sequence_id`` | string | optional; use with steel sync floats |
--- | ``start_delay_ms`` | integer | optional |
--- | ``duration_ms`` | integer | optional (default 1 in registry; sequencing only) |
--- | ``parallel`` | boolean | optional |
---
--- **Edge cases**
---
--- * Multiple owners: ``presented`` is keyed by ``B`` / ``W``.
--- * Fields without any ``display_update_*`` in the batch use **authoritative** (post-resolve) immediately on the HUD; stepped fields start from **baseline** (pre-resolve).
--- * If ``x_mult`` changes in resolve but no ``display_update_x_mult`` intents are emitted, rollout is inactive and the HUD shows authoritative (no drift).
--- * A new rollout calls ``end_rollout`` first so stale presentation state cannot stack.
---
--- @module ui.score_display

local config = require("config")
local match_state = require("match_state")

local M = {}

local ROLL_KEY = "_score_display_rollout"

local FIELD_BY_INTENT_TYPE = {
	display_update_territory = "territory",
	display_update_points = "points",
	display_update_plus_mult = "plus_mult",
	display_update_x_mult = "x_mult",
}

local SCORE_FIELDS = { "turn_bonus", "territory", "points", "plus_mult", "x_mult" }

--- @param intent_type string
--- @return boolean
local function is_display_intent_type(intent_type)
	return FIELD_BY_INTENT_TYPE[intent_type] ~= nil
end

--- @param intents table[]|nil
--- @return boolean
function M.intent_list_has_display_updates(intents)
	if not intents then
		return false
	end
	for i = 1, #intents do
		local it = intents[i]
		local t = it and it.type
		if is_display_intent_type(t) then
			return true
		end
		if t == "hand_card_float_text" and type(it.presented_x_mult) == "number" then
			return true
		end
	end
	return false
end

--- @param score table|nil
--- @return table
local function copy_score_slice(score)
	local s = score or {}
	return {
		turn_bonus = s.turn_bonus or 1,
		territory = s.territory or 0,
		points = s.points or 0,
		plus_mult = s.plus_mult or 1,
		x_mult = s.x_mult or 1,
	}
end

--- @param state table
--- @return table  keys ``B``, ``W`` each a numeric score slice
function M.snapshot_scores(state)
	local black = match_state.player_for_color(state, "black")
	local white = match_state.player_for_color(state, "white")
	return {
		B = copy_score_slice(black and black.score),
		W = copy_score_slice(white and white.score),
	}
end

--- @param intents table[]|nil
--- @return table<string, table<string, boolean>>  stepped[owner][field] = true
local function stepped_fields_from_intents(intents)
	local stepped = {}
	if not intents then
		return stepped
	end
	for i = 1, #intents do
		local it = intents[i]
		local owner = it and it.owner
		if owner == config.OWNER_BLACK or owner == config.OWNER_WHITE then
			local field = FIELD_BY_INTENT_TYPE[it.type]
			if field then
				stepped[owner] = stepped[owner] or {}
				stepped[owner][field] = true
			elseif it.type == "hand_card_float_text" and type(it.presented_x_mult) == "number" then
				stepped[owner] = stepped[owner] or {}
				stepped[owner].x_mult = true
			end
		end
	end
	return stepped
end

--- @param state table
--- @param baseline table  from ``snapshot_scores`` before resolve
--- @param intents table[]|nil  ``state.ui_animation_events`` after resolve
--- @return nil
function M.after_resolve(state, baseline, intents)
	if not state or not baseline then
		return
	end
	M.end_rollout(state)
	if not M.intent_list_has_display_updates(intents) then
		return
	end
	local authoritative = M.snapshot_scores(state)
	local stepped = stepped_fields_from_intents(intents)
	local presented = { B = {}, W = {} }
	for _, owner in ipairs({ config.OWNER_BLACK, config.OWNER_WHITE }) do
		local base_o = baseline[owner] or {}
		local auth_o = authoritative[owner] or {}
		local row = {}
		for f = 1, #SCORE_FIELDS do
			local field = SCORE_FIELDS[f]
			if stepped[owner] and stepped[owner][field] then
				row[field] = base_o[field]
			else
				row[field] = auth_o[field]
			end
		end
		presented[owner] = row
	end
	state[ROLL_KEY] = { presented = presented }
end

--- @param state table
--- @return nil
function M.end_rollout(state)
	if state then
		state[ROLL_KEY] = nil
	end
end

--- @param state table
--- @return boolean
function M.is_rollout_active(state)
	return state and state[ROLL_KEY] ~= nil
end

--- @param state table
--- @param side string ``"black"`` | ``"white"``
--- @return table  score-like row for drawing (shallow; do not mutate)
function M.effective_row(state, side)
	local owner = (side == "black" or side == config.STONE_BLACK) and config.OWNER_BLACK or config.OWNER_WHITE
	local roll = state and state[ROLL_KEY]
	if roll and roll.presented and roll.presented[owner] then
		return roll.presented[owner]
	end
	local p = match_state.player_for_color(state, side)
	return p and p.score or {}
end

--- Total aligned with ``draw_score_box_detailed`` / ``sync_player_scores`` math.
--- @param row table
--- @return integer
function M.calculate_display_total(row)
	local r = row or {}
	local turn_bonus = r.turn_bonus or 1
	local territory = math.ceil(r.territory or 0)
	local points = math.ceil(r.points or 0)
	local plus_mult = math.ceil(r.plus_mult or 1)
	local x_mult = r.x_mult or 1
	return math.ceil(turn_bonus * territory * points * plus_mult * x_mult)
end

--- Sets one presented score field during rollout. Does not touch ``player.score``.
--- @param state table
--- @param owner string ``config.OWNER_BLACK`` | ``config.OWNER_WHITE``
--- @param field string ``territory`` | ``points`` | ``plus_mult`` | ``x_mult``
--- @param value number
--- @return nil
function M.apply_field_value(state, owner, field, value)
	local roll = state and state[ROLL_KEY]
	if not roll or not roll.presented or not owner or not field then
		return
	end
	local row = roll.presented[owner]
	if not row then
		return
	end
	row[field] = value
end

--- Applies ``display_update_*`` job at **job start** (first tick with ``age >= delay_start_s``). Does not touch ``player.score``.
--- @param job table
--- @param state table
--- @return nil
function M.apply_display_job_at_start(job, state)
	if not job or not state or job._display_value_applied then
		return
	end
	if type(job.animation_id) ~= "string" or job.animation_id:sub(1, 15) ~= "display_update_" then
		return
	end
	if job.age < job.delay_start_s then
		return
	end
	M.apply_field_value(state, job.owner, job.field, job.value)
	job._display_value_applied = true
end

--- Applies ``hand_card_float_text.presented_x_mult`` at float **start** (same moment the ``×`` label appears).
--- @param job table
--- @param state table
--- @return nil
function M.apply_hand_float_x_mult_at_start(job, state)
	if not job or not state or job._score_x_mult_applied then
		return
	end
	if job.animation_id ~= "hand_card_float_text" or type(job.presented_x_mult) ~= "number" then
		return
	end
	if job.age < job.delay_start_s then
		return
	end
	M.apply_field_value(state, job.owner, "x_mult", job.presented_x_mult)
	job._score_x_mult_applied = true
end

return M
