--- Wall-clock start offsets (milliseconds) for UI animation intents in one drain batch.
---
--- **Grouping**: ``sequence_id`` (non-empty string). Intents without it are independent: effective start =
--- ``start_delay_ms`` only.
---
--- **Sequential (default in a sequence)**: For intents sharing ``sequence_id`` with ``parallel`` not true,
--- effective start = ``sequential_tail + start_delay_ms``, then tail advances by ``resolved_duration_ms``.
---
--- **Parallel**: ``parallel`` = true — effective start = ``start_delay_ms`` from batch T=0; tail becomes
--- ``max(previous_tail, start_delay_ms + resolved_duration_ms)`` so the next non-parallel step starts after
--- any overlap ends.
---
--- Durations come from ``ui.animation_kinds.resolved_duration_ms`` (registry defaults merged with intent).
---
--- @module ui.animation_schedule

local animation_kinds = require("ui.animation_kinds")

local M = {}

--- @param intents table[]
--- @return integer[]
function M.effective_start_ms_list(intents)
	local out = {}
	local sequential_tail = {}
	for i = 1, #intents do
		local intent = intents[i]
		local sid = intent.sequence_id
		local has_sid = type(sid) == "string" and sid ~= ""
		local eff_ms
		if intent.parallel then
			eff_ms = intent.start_delay_ms or 0
			if has_sid then
				local dur = animation_kinds.resolved_duration_ms(intent)
				local end_ms = eff_ms + dur
				local prev = sequential_tail[sid] or 0
				sequential_tail[sid] = math.max(prev, end_ms)
			end
		elseif has_sid then
			local base = sequential_tail[sid] or 0
			eff_ms = base + (intent.start_delay_ms or 0)
			local dur = animation_kinds.resolved_duration_ms(intent)
			sequential_tail[sid] = eff_ms + dur
		else
			eff_ms = intent.start_delay_ms or 0
		end
		out[i] = eff_ms
	end
	return out
end

return M
