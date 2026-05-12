--- Tunable scalar constants for gameplay-driven UI animations (no LÖVE). Steel hand-float values are read by
--- ``objects.animations_helper.steel_hand_float_step_duration_ms``.
--- @module objects.animations_constants

local M = {}

--- Soft budget: total ms targeted across all steel-card float steps (minimum per card may force real sum higher).
M.STEEL_HAND_FLOAT_TARGET_TOTAL_MS = 1200

--- Floor ms per steel float step when splitting the budget across ``N`` steel cards.
M.STEEL_HAND_FLOAT_MIN_PER_CARD_MS = 200

return M
