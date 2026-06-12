--- Runs board-reconcile lifecycle effects once after board topology changes.
--- @module single_game.resolver.board_reconcile

local content = require("content")
local effect_registry = require("effect_registry")

local M = {}

--- @return table
local function collect_board_reconcile_effect_defs()
	local seen = {}
	local effects = {}
	for _, stone_def in pairs(content.stones) do
		if type(stone_def) == "table" and stone_def.effects then
			for i = 1, #stone_def.effects do
				local effect_def = stone_def.effects[i]
				if effect_def.macro == "board_reconcile" then
					local name = effect_def.effect_name
					if name and not seen[name] then
						seen[name] = true
						effects[#effects + 1] = effect_def
					end
				end
			end
		end
	end
	table.sort(effects, function(a, b)
		return (a.priority or 10) < (b.priority or 10)
	end)
	return effects
end

local BOARD_RECONCILE_EFFECTS = collect_board_reconcile_effect_defs()

--- Reapply board-wide derived cell state after placement, capture, or removal.
--- @param state table
--- @return nil
function M.run(state)
	for i = 1, #BOARD_RECONCILE_EFFECTS do
		local effect_def = BOARD_RECONCILE_EFFECTS[i]
		local resolved = effect_registry.stones.resolve(effect_def)
		if resolved and resolved.apply then
			resolved.apply(state)
		end
	end
end

return M
