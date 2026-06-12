--- Central content loader: loads all definitions from objects/
---
--- **Adding content (graphics-first)**:
--- 1. **Stones** — ``objects/definitions/stones.lua``: gameplay + ``visual.color`` + ``visual.sprite`` (PNG path).
--- 2. **Cards** — ``objects/definitions/cards.lua``: gameplay + ``visual`` (see ``ui.card_visual`` defaults / schema in cards module).
--- 3. **Stances** — ``objects/definitions/stances.lua``: gameplay + ``visual.graphic`` + ``visual.frame``.
--- 4. Register pools / starters in ``game_types`` and ``content.starters`` as needed.
--- @module content

local M = {}

local schema = require("objects.schema")
local stone_resolve = require("objects.stone_resolve")

--- Load all definitions from unified objects/ module
M.stones = require("objects.definitions.stones")
M.stances = require("objects.definitions.stances")
M.cards = require("objects.definitions.cards")

--- Validate all definitions at load time
local function validate_all_definitions()
	local valid, errors

	valid, errors = schema.validate_all(M.stones, "stone")
	if not valid then
		print("[ERROR] Stone validation failed:")
		for _, err in ipairs(errors) do
			print("  - " .. err)
		end
	end

	valid, errors = schema.validate_all(M.stances, "stance")
	if not valid then
		print("[ERROR] Stance validation failed:")
		for _, err in ipairs(errors) do
			print("  - " .. err)
		end
	end

	valid, errors = schema.validate_all(M.cards, "card")
	if not valid then
		print("[ERROR] Card validation failed:")
		for _, err in ipairs(errors) do
			print("  - " .. err)
		end
	end
end

validate_all_definitions()

M.starters = {
	black = {
		stances = {
			fixed = { "stance_point" },
			swappable = { "stance_mult" },
		},
		pouch = {
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_power",
			"stone_power",
			"stone_power",
			"stone_focus",
			"stone_focus",
			"stone_focus",
		},
		deck = {
			"card_point_tap",
			"card_point_tap",
			"card_point_tap",
			"card_point_push",
			"card_point_push",
			"card_small_mult",
			"card_small_mult",
			"card_big_mult",
			"card_balanced_boost",
			"card_balanced_boost",
		},
	},
	white = {
		stances = {
			fixed = { "stance_mult" },
			swappable = { "stance_heavy_point" },
		},
		pouch = {
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_power",
			"stone_power",
			"stone_power",
			"stone_focus",
			"stone_focus",
			"stone_focus",
		},
		deck = {
			"card_point_tap",
			"card_point_tap",
			"card_point_tap",
			"card_point_push",
			"card_point_push",
			"card_small_mult",
			"card_small_mult",
			"card_big_mult",
			"card_balanced_boost",
			"card_balanced_boost",
		},
	},
}

--- Get stone definition by ID.
--- @param stone_id string
--- @return table|nil
function M.get_stone(stone_id)
	if stone_id == "stone_wall" then
		stone_id = "wall"
	end
	return M.stones[stone_id]
end

--- Resolve stone def for placement: base def plus cumulative level deltas.
--- String ref returns the static definition. Table ref uses def_id + level (clamped to max_level).
--- Levels above the last defined upgrade_levels entry keep prior cumulative deltas only.
--- @param stone_ref string|table
--- @return table|nil
function M.resolve_stone(stone_ref)
	if type(stone_ref) == "string" then
		return M.get_stone(stone_ref)
	end
	if type(stone_ref) ~= "table" then
		return nil
	end
	local def_id = stone_ref.def_id or stone_ref.id
	if not def_id then
		return nil
	end
	local def = M.get_stone(def_id)
	if not def then
		return nil
	end
	local level = stone_ref.level or 1
	level = math.max(1, level)
	if def.unlimited_levels then
		return stone_resolve.resolve_unlimited_upgrades_at_level(def, level)
	end
	local max_level = def.max_level or 1
	level = math.min(level, max_level)
	return stone_resolve.resolve_stone_def_at_level(def, level)
end

--- Get card definition by ID.
--- @param card_id string
--- @return table|nil
function M.get_card(card_id)
	return M.cards[card_id]
end

--- Get stance definition by ID. Replaces old get_pose.
--- @param stance_id string
--- @return table|nil
function M.get_stance(stance_id)
	return M.stances[stance_id]
end

return M
