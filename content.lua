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
	return M.stones[stone_id]
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
