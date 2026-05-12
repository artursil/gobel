--- Producer API for UI animation **intents** appended to ``state.ui_animation_events``. The **consumer**
--- is ``require("ui.animations")`` (LÖVE drain/draw); this module never touches graphics.
---
--- Steel hand-float timing knobs live in ``objects.animations_constants``. Other animation defaults live in
--- ``ui.animation_kinds`` defaults tables.
---
--- Per-animation intent logic lives in ``objects.animations_definitions``. This module registers definitions in
--- ``builders`` (name → function) and exposes ``add_animation(name)(state, args)``. Gameplay calls
--- ``animations.add_animation("<name>")(state, { ... })`` with minimal args (no intent shapes in
--- ``objects/effects.lua``).
---
--- @module objects.animations

local definitions = require("objects.animations_definitions")

local builders = {
	steel_sync_mult = definitions.steel_sync_mult,
}

local M = {}

--- Returns a runner ``function(state, args)`` for the named animation.
--- @param name string
--- @return fun(state: table, args: table): nil
function M.add_animation(name)
	local fn = builders[name]
	if not fn then
		error("unknown animation: " .. tostring(name))
	end
	return function(state, args)
		return fn(state, args or {})
	end
end

return M
