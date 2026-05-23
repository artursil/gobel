--- Gameplay-to-presentation bridge for short UI motion driven by scoring effects.
---
--- **Intent schema**: plain tables on ``game.ui_animation_events``; builders emit them from
--- ``objects.animations_definitions`` via ``objects.animations.add_animation``; see ``ui.animation_schedule``
--- and ``ui.animation_kinds``. ``type`` must match a registry key. ``display_update_*`` intents adjust only
--- the HUD via ``ui.score_display`` (authoritative ``player.score`` unchanged after resolve).
---
--- **Drain policy**: Each ``love.update`` tick, ``render.update`` calls ``update``, which runs
--- ``drain_state_intents`` first: ``ui.animation_schedule.effective_start_ms_list`` resolves wall-clock
--- ``start_delay_ms`` per intent (sequential by ``sequence_id`` unless ``parallel``); each intent is
--- spawned via ``ui.animation_kinds.spawn_job_from_intent`` with scheduling meta stripped. The match state's
--- list is cleared afterward.
---
--- **Threading**: Single-threaded; ``ui.animation_kinds.tick_job_age`` advances each job's ``age``.
--- ``display_update_*`` jobs apply at **job start** (see ``ui.score_display.apply_display_job_at_start``) before age tick.
--- When ``active_jobs`` becomes empty, ``ui.score_display.end_rollout`` runs so the HUD reads authoritative scores again.
---
--- @module ui.animations

local config = require("config")
local content = require("content")
local layout_mod = require("layout")
local match_state = require("match_state")
local stances = require("stances")
local animation_kinds = require("ui.animation_kinds")
local animation_schedule = require("ui.animation_schedule")
local ui_fonts = require("ui.fonts")
local score_display = require("ui.score_display")

local M = {}

local active_jobs = {}

--- While a stance shake is drawing that slot, the static tile is omitted to avoid double art.
--- @param owner_key string
--- @param lane_index integer
--- @return boolean
function M.stance_shake_replaces_slot(owner_key, lane_index)
	for j = 1, #active_jobs do
		local job = active_jobs[j]
		if job.animation_id == "stance_shake" and job.owner == owner_key and job.stance_slot_index == lane_index then
			if job.age >= job.delay_start_s and job.age < job.delay_start_s + job.dur_s then
				return true
			end
		end
	end
	return false
end

--- @return boolean
function M.has_active_jobs()
	return #active_jobs > 0
end

--- Stance card layout aligned with ``render.draw_stances`` / hit testing.
--- @param box table
--- @param stance_count integer
--- @return table[]
local function stance_card_rects_for_panel(box, stance_count)
	local cards = {}
	local count = stance_count
	if count == 0 then
		return cards
	end
	local cols = 2
	local gap_x = 8
	local gap_y = 10
	local pad = 10
	local title_h = 28
	local card_w = math.floor((box.w - pad * 2 - gap_x) / cols)
	card_w = math.max(72, card_w)
	local card_h = math.max(82, math.floor(card_w * 1.4))
	local rows = math.ceil(count / cols)
	local usable_h = math.max(1, box.h - title_h - pad)
	local total_h = rows * card_h + math.max(0, rows - 1) * gap_y
	local step_y = card_h + gap_y
	if total_h > usable_h and rows > 1 then
		step_y = (usable_h - card_h) / (rows - 1)
		step_y = math.min(card_h + gap_y, step_y)
	end
	for i = 1, count do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		cards[i] = {
			x = box.x + pad + col * (card_w + gap_x),
			y = box.y + title_h + row * step_y,
			w = card_w,
			h = card_h,
		}
	end
	return cards
end

--- @param base table
--- @param effective_start_ms number
--- @return table
local function intent_clone_for_spawn(base, effective_start_ms)
	local t = {}
	for k, v in pairs(base) do
		if k ~= "sequence_id" and k ~= "parallel" then
			t[k] = v
		end
	end
	t.start_delay_ms = effective_start_ms
	return t
end

--- Returns stance lane rects and hand slot centers for animation anchoring.
---
--- **Hand slots**: ``hand_slot_center`` resolves anchors for ``config.OWNER_BLACK`` using ``layout.hand_panel``
--- (bottom human hand). For ``config.OWNER_WHITE`` this API currently returns nil — there is no dedicated
--- opponent hand rect in layout; ``hand_card_float_text`` jobs for white owners draw nothing until layout
--- exposes opponent hand geometry.
--- @param game table
--- @param layout table
--- @return table
function M.build_ui_target_index(game, layout)
	local function stance_panel_and_entries(owner_key)
		if owner_key == config.OWNER_BLACK then
			return layout.player_stances_panel, stances.all_active_stances(match_state.player_for_color(game, "black"), game, owner_key)
		end
		return layout.opponent_stances_panel, stances.all_active_stances(match_state.player_for_color(game, "white"), game, owner_key)
	end

	local function stance_card_rect(owner_key, lane_index)
		local box, entries = stance_panel_and_entries(owner_key)
		if not box or lane_index < 1 or lane_index > #entries then
			return nil
		end
		local rects = stance_card_rects_for_panel(box, #entries)
		return rects[lane_index]
	end

	local function hand_slot_center(owner_key, hand_index)
		if owner_key == config.OWNER_WHITE then
			return nil, nil
		end
		if owner_key ~= config.OWNER_BLACK then
			return nil, nil
		end
		local player = match_state.player_for_color(game, "black")
		local ids = player.cards.hand and player.cards.hand.ids or {}
		local n = #ids
		if hand_index < 1 or hand_index > n then
			return nil, nil
		end
		local slots = layout_mod.hand_fan_slots(layout, n)
		local s = slots[hand_index]
		if not s then
			return nil, nil
		end
		local cx = s.x + s.w * 0.5
		local cy = s.y + s.h * 0.22
		return cx, cy
	end

	local function stance_at_slot(owner_key, lane_index)
		local box, entries = stance_panel_and_entries(owner_key)
		if not box or not entries or lane_index < 1 or lane_index > #entries then
			return nil
		end
		local entry = entries[lane_index]
		local stance_id = entry.id or entry
		return content.get_stance(stance_id)
	end

	return {
		layout = layout,
		stance_card_rect = stance_card_rect,
		stance_at_slot = stance_at_slot,
		hand_slot_center = hand_slot_center,
	}
end

--- Drains ``game.ui_animation_events`` into ``active_jobs`` via the animation registry, then clears the state list.
--- @param game table
--- @param layout table
--- @return nil
function M.drain_state_intents(game, layout)
	if not game or not layout then
		return
	end
	local list = game.ui_animation_events
	if not list or #list == 0 then
		return
	end
	local eff_ms_list = animation_schedule.effective_start_ms_list(list)
	for i = 1, #list do
		local intent = list[i]
		local spawn_intent = intent_clone_for_spawn(intent, eff_ms_list[i])
		local job = animation_kinds.spawn_job_from_intent(spawn_intent, game, layout)
		if job then
			active_jobs[#active_jobs + 1] = job
		end
	end
	game.ui_animation_events = {}
end

--- @param dt number
--- @param game table
--- @param layout table
--- @return nil
function M.update(dt, game, layout)
	M.drain_state_intents(game, layout)
	for ji = 1, #active_jobs do
		local j = active_jobs[ji]
		score_display.apply_display_job_at_start(j, game)
		score_display.apply_hand_float_x_mult_at_start(j, game)
	end
	for i = #active_jobs, 1, -1 do
		local j = active_jobs[i]
		if animation_kinds.tick_job_age(j, dt) then
			table.remove(active_jobs, i)
		end
	end
	if #active_jobs == 0 then
		score_display.end_rollout(game)
	end
end

--- @param game table
--- @param layout table
--- @return nil
function M.draw(game, layout)
	if not game or not layout then
		return
	end
	local lg = love.graphics
	local idx = M.build_ui_target_index(game, layout)
	for _, j in ipairs(active_jobs) do
		animation_kinds.draw_job(j, idx)
	end
	ui_fonts.apply_default()
	lg.setColor(1, 1, 1, 1)
end

return M
