--- Registry of UI animation kinds keyed by intent ``type`` (same string as ``job.animation_id``).
---
--- **Intent** (element of ``game.ui_animation_events`` before drain): plain table with required ``type``
--- (``"stance_shake"`` | ``"hand_card_float_text"``). Optional fields override that kind's ``defaults``.
--- For ``hand_card_float_text``, optional ``font_size_px`` sets the cached LÖVE font pixel height for the label.
--- Stance shake: ``stance_slot_index`` (1-based on that owner's stance panel). Optional ``stance_def_id`` / ``stance_instance_id`` for telemetry.
---
--- Optional ``sequence_id`` (non-empty string): intents in one drain pass with the same id default to **sequential**
--- scheduling — each step's effective wall-clock start is the prior step's end plus this intent's ``start_delay_ms``.
--- ``parallel`` = true opts out: effective start is only ``start_delay_ms`` from batch T=0; the step still updates
--- the sequence tail to ``max(tail, start_delay_ms + duration_ms)`` so the next non-parallel step waits for overlap
--- to finish. Intents without ``sequence_id`` use ``start_delay_ms`` alone (no cross-intent chaining).
--- ``sequence_id``, ``parallel``, and ``type`` are not merged onto animation payloads. Unknown ``type`` values are ignored.
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
	shake_amp_max = 5,
	shake_freq_sin = 16,
	shake_freq_cos = 14,
	line_width = 3,
	line_r = 0.95,
	line_g = 0.55,
	line_b = 0.15,
	line_alpha_peak = 0.45,
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
		shake_freq_sin = m.shake_freq_sin,
		shake_freq_cos = m.shake_freq_cos,
		line_width = m.line_width,
		line_r = m.line_r,
		line_g = m.line_g,
		line_b = m.line_b,
		line_alpha_peak = m.line_alpha_peak,
	}
end

--- Draws a pulsing offset outline around the stance lane rect.
--- @param job table
--- @param ui_index table
--- @return nil
function stance_shake.draw(job, ui_index)
	if job.age < job.delay_start_s then
		return
	end
	local rect = ui_index.stance_card_rect(job.owner, job.stance_slot_index)
	if not rect then
		return
	end
	local lg = love.graphics
	local u = (job.age - job.delay_start_s) / math.max(0.0001, job.dur_s)
	local amp = job.shake_amp_max * (1 - u)
	local ox = math.sin(job.age * job.shake_freq_sin) * amp
	local oy = math.cos(job.age * job.shake_freq_cos) * amp * 0.6
	lg.setColor(job.line_r, job.line_g, job.line_b, job.line_alpha_peak * (1 - u))
	lg.setLineWidth(job.line_width)
	lg.rectangle("line", rect.x + ox, rect.y + oy, rect.w, rect.h, 8, 8)
	lg.setLineWidth(1)
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
	return {
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
	}
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
	local prev_font = nil
	if float_font and lg.getFont then
		prev_font = lg.getFont()
		lg.setFont(float_font)
	end
	lg.printf(job.text, cx - job.text_half_width, cy - rise - job.text_offset_y, w, "center")
	if prev_font and lg.setFont then
		lg.setFont(prev_font)
	end
end

M.by_id = {
	stance_shake = stance_shake,
	hand_card_float_text = hand_card_float_text,
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
