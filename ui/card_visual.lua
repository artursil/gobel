--- Merged **card.visual** fields with documented defaults (see module docstring on ``objects.definitions.cards``).
--- @module ui.card_visual

local M = {}

--- @type table
M.defaults = {
	background = "sprites/cards/background_1_r.png",
	graphic = "sprites/cards/graphic_default.png",
	border_color = "#E6CDA4",
	title_box_color = "#FFFFFF",
	description_box_color = "#E6CDA4",
	circle_color = "#B43321",
}

--- @param hex string  ``#RRGGBB`` or ``RRGGBB``
--- @return number r
--- @return number g
--- @return number b
--- @return number a
function M.rgba_from_hex(hex)
	local s = hex
	if type(s) ~= "string" then
		return 1, 1, 1, 1
	end
	if string.sub(s, 1, 1) == "#" then
		s = string.sub(s, 2)
	end
	if #s < 6 then
		return 1, 1, 1, 1
	end
	local r = tonumber(string.sub(s, 1, 2), 16) or 255
	local g = tonumber(string.sub(s, 3, 4), 16) or 255
	local b = tonumber(string.sub(s, 5, 6), 16) or 255
	return r / 255, g / 255, b / 255, 1
end

--- @param card table
--- @return table
function M.merged(card)
	local v = (card and card.visual) or {}
	local out = {}
	for k, def in pairs(M.defaults) do
		out[k] = v[k] ~= nil and v[k] or def
	end
	for k, val in pairs(v) do
		out[k] = val
	end
	return out
end

return M
