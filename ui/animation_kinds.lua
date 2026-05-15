--- Registry of UI animation kinds keyed by intent ``type`` (same string as ``job.animation_id``).
---
--- **Intent** (element of ``game.ui_animation_events`` before drain): plain table with required ``type``
--- (``"stance_shake"`` | ``"hand_card_float_text"`` | ``"display_update_territory"`` | ``"display_update_points"`` |
--- ``"display_update_plus_mult"`` | ``"display_update_x_mult"``). Optional fields override that kind's ``defaults``.
--- For ``hand_card_float_text``, optional ``font_size_px`` sets the cached LÖVE font pixel height for the label.
--- Stance shake: ``stance_slot_index`` (1-based on that owner's stance panel). Shakes portrait + frame as one unit. Optional ``stance_def_id`` / ``stance_instance_id`` for telemetry.
---
--- Optional ``sequence_id`` (non-empty string): intents in one drain pass with the same id default to **sequential**
--- scheduling — each step's effective wall-clock start is the prior step's end plus this intent's ``start_delay_ms``.
--- ``parallel`` = true opts out: effective start is only ``start_delay_ms`` from batch T=0; the step still updates
--- the sequence tail to ``max(tail, start_delay_ms + duration_ms)`` so the next non-parallel step waits for overlap
--- to finish. Intents without ``sequence_id`` use ``start_delay_ms`` alone (no cross-intent chaining).
--- ``sequence_id``, ``parallel``, and ``type`` are not merged onto animation payloads. Unknown ``type`` values are ignored.
---
--- **display_update_***: visual-only score HUD steps; ``owner`` + ``value`` (number shown after this step, Option A).
--- Jobs apply at **start** (first frame with ``age >= delay_start_s``); default ``duration_ms`` is 1 for sequencing.
---
--- **Job** (runtime queue entry): plain table with ``animation_id``, ``age``, ``delay_start_s``, ``dur_s``,
--- plus kind-specific numeric/string fields copied at spawn. No functions or userdata.
---
--- **Defaults**: each kind owns a ``defaults`` table (durations, motion, colors). ``spawn`` merges
--- ``defaults`` with the intent (intent wins); missing required targeting fields yield no job.
---
--- **Drain policy**: unchanged from ``ui.animations`` — ``drain_state_intents`` runs inside ``update``,
--- spawns jobs via this registry, then clears ``game.ui_animation_events``.
---
--- @module ui.animation_kinds

local M = {}

local stance_card_draw = require("ui.stance_card_draw")

local hand_float_font_cache = {}

local ui_fonts_mod = nil

--- @param px integer
--- @return userdata|nil
local function cached_hand_float_font(px)
	local lg = love.graphics
	if not lg or not lg.newFont then
		return nil
	end
	local f = hand_float_font_cache[px]
	if f then
		return f
	end
	ui_fonts_mod = ui_fonts_mod or require("ui.fonts")
	f = ui_fonts_mod.get_pixel_operator(px)
	hand_float_font_cache[px] = f
	return f
end

local function is_intent_meta_key(k)
	return k == "type" or k == "sequence_id" or k == "parallel"
end

--- @param defaults table
--- @param intent table|nil
--- @return table
local function merge_defaults(defaults, intent)
	local m = {}
	for k, v in pairs(defaults) do
		m[k] = v
	end
	if intent then
		for k, v in pairs(intent) do
			if not is_intent_meta_key(k) and v ~= nil then
				m[k] = v
			end
		end
	end
	return m
end

--- @param job table
--- @return number
local function job_end_time_s(job)
	return job.delay_start_s + job.dur_s
end

local stance_shake = {}

stance_shake.defaults = {
	duration_ms = 1020,
	start_delay_ms = 0,
	shake_amp_max = 6,
	shake_rot_max = 0.055,
	shake_freq_sin = 22,
	shake_freq_cos = 19,
}

--- Builds a stance shake job from a merged intent, or returns nil if targeting is incomplete.
--- @param intent table
--- @param game table|nil
--- @param layout table|nil
--- @return table|nil
function stance_shake.spawn(intent, game, layout)
	local m = merge_defaults(stance_shake.defaults, intent)
	if not m.owner or m.stance_slot_index == nil then
		return nil
	end
	return {
		animation_id = "stance_shake",
		age = 0,
		delay_start_s = (m.start_delay_ms or 0) / 1000,
		dur_s = (m.duration_ms or stance_shake.defaults.duration_ms) / 1000,
		owner = m.owner,
		stance_slot_index = m.stance_slot_index,
		shake_amp_max = m.shake_amp_max,
		shake_rot_max = m.shake_rot_max,
		shake_freq_sin = m.shake_freq_sin,
		shake_freq_cos = m.shake_freq_cos,
	}
end

--- Shakes the stance portrait and frame as one unit (translate + slight rotation).
--- @param job table
--- @param ui_index table
--- @return nil
function stance_shake.draw(job, ui_index)
	if job.age < job.delay_start_s then
		return
	end
	local rect = ui_index.stance_card_rect(job.owner, job.stance_slot_index)
	local stance = ui_index.stance_at_slot(job.owner, job.stance_slot_index)
	if not rect or not stance then
		return
	end
	local lg = love.graphics
	local u = (job.age - job.delay_start_s) / math.max(0.0001, job.dur_s)
	local amp = job.shake_amp_max * (1 - u)
	local ox = math.sin(job.age * job.shake_freq_sin) * amp
	local oy = math.cos(job.age * job.shake_freq_cos) * amp * 0.65
	local rot = math.sin(job.age * job.shake_freq_sin * 0.73) * job.shake_rot_max * (1 - u)
	local cx = rect.x + rect.w * 0.5
	local cy = rect.y + rect.h * 0.5
	lg.push()
	lg.translate(cx, cy)
	lg.rotate(rot)
	lg.translate(-cx, -cy)
	lg.translate(ox, oy)
	stance_card_draw.draw_portrait_and_frame(rect, stance)
	lg.pop()
	lg.setColor(1, 1, 1, 1)
end

local hand_card_float_text = {}

hand_card_float_text.defaults = {
	duration_ms = 1000,
	start_delay_ms = 0,
	rise_px = 52,
	text_half_width = 80,
	text_offset_y = 18,
	font_size_px = 32,
	text_r = 0.95,
	text_g = 0.86,
	text_b = 0.25,
}

--- Builds a floating hand-label job, or nil if text or indices are missing.
--- @param intent table
--- @param game table|nil
--- @param layout table|nil
--- @return table|nil
function hand_card_float_text.spawn(intent, game, layout)
	local m = merge_defaults(hand_card_float_text.defaults, intent)
	if not m.owner or m.hand_index == nil or m.text == nil or m.text == "" then
		return nil
	end
	local job = {
		animation_id = "hand_card_float_text",
		age = 0,
		delay_start_s = (m.start_delay_ms or 0) / 1000,
		dur_s = (m.duration_ms or hand_card_float_text.defaults.duration_ms) / 1000,
		owner = m.owner,
		hand_index = m.hand_index,
		text = m.text,
		rise_px = m.rise_px,
		text_half_width = m.text_half_width,
		text_offset_y = m.text_offset_y,
		font_size_px = m.font_size_px,
		text_r = m.text_r,
		text_g = m.text_g,
		text_b = m.text_b,
		_score_x_mult_applied = false,
	}
	if type(m.presented_x_mult) == "number" then
		job.presented_x_mult = m.presented_x_mult
	end
	return job
end

--- Draws rising label text above the hand slot. Skips when no anchor (e.g. white owner until layout adds opponent hand rects).
--- @param job table
--- @param ui_index table
--- @return nil
function hand_card_float_text.draw(job, ui_index)
	if job.age < job.delay_start_s then
		return
	end
	local cx, cy = ui_index.hand_slot_center(job.owner, job.hand_index)
	if not cx or not cy then
		return
	end
	local lg = love.graphics
	local u = (job.age - job.delay_start_s) / math.max(0.0001, job.dur_s)
	local rise = job.rise_px * u
	local alpha = 1 - u * u
	lg.setColor(job.text_r, job.text_g, job.text_b, math.max(0, math.min(1, alpha)))
	local w = job.text_half_width * 2
	local float_font = cached_hand_float_font(job.font_size_px)
	if float_font and lg.setFont then
		lg.setFont(float_font)
	end
	lg.printf(job.text, cx - job.text_half_width, cy - rise - job.text_offset_y, w, "center")
	ui_fonts_mod = ui_fonts_mod or require("ui.fonts")
	ui_fonts_mod.apply_default()
	lg.setColor(1, 1, 1, 1)
end

local function make_display_update_kind(animation_id, field_name)
	local kind = {}
	kind.defaults = {
		duration_ms = 1,
		start_delay_ms = 0,
	}
	function kind.spawn(intent, game, layout)
		local m = merge_defaults(kind.defaults, intent)
		if not m.owner or type(m.value) ~= "number" then
			return nil
		end
		return {
			animation_id = animation_id,
			age = 0,
			delay_start_s = (m.start_delay_ms or 0) / 1000,
			dur_s = math.max(0.001, (m.duration_ms or kind.defaults.duration_ms) / 1000),
			owner = m.owner,
			field = field_name,
			value = m.value,
			_display_value_applied = false,
		}
	end
	return kind
end

M.by_id = {
	stance_shake = stance_shake,
	hand_card_float_text = hand_card_float_text,
	display_update_territory = make_display_update_kind("display_update_territory", "territory"),
	display_update_points = make_display_update_kind("display_update_points", "points"),
	display_update_plus_mult = make_display_update_kind("display_update_plus_mult", "plus_mult"),
	display_update_x_mult = make_display_update_kind("display_update_x_mult", "x_mult"),
}

--- Merged ``duration_ms`` for an intent (registry defaults plus intent overrides). Used by the scheduler.
--- @param intent table
--- @return integer
function M.resolved_duration_ms(intent)
	if not intent or type(intent.type) ~= "string" then
		return 0
	end
	local kind = M.by_id[intent.type]
	if not kind or not kind.defaults then
		return 0
	end
	local m = merge_defaults(kind.defaults, intent)
	local d = m.duration_ms
	if type(d) ~= "number" or d < 0 then
		return 0
	end
	return math.floor(d + 0.5)
end

--- @param intent table
--- @param game table|nil
--- @param layout table|nil
--- @return table|nil
function M.spawn_job_from_intent(intent, game, layout)
	if not intent or type(intent.type) ~= "string" then
		return nil
	end
	local kind = M.by_id[intent.type]
	if not kind or not kind.spawn then
		return nil
	end
	return kind.spawn(intent, game, layout)
end

--- @param job table
--- @param ui_index table
--- @return nil
function M.draw_job(job, ui_index)
	if not job or type(job.animation_id) ~= "string" then
		return
	end
	local kind = M.by_id[job.animation_id]
	if kind and kind.draw then
		kind.draw(job, ui_index)
	end
end

--- @param job table
--- @param dt number
--- @return boolean  true when the job should be removed
function M.tick_job_age(job, dt)
	job.age = job.age + dt
	return job.age >= job_end_time_s(job)
end

return M
