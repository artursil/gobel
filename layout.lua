--- Maps between window pixels and board grid intersections.

local config = require("config")

local M = {}

--- Computes pixel origin, cell spacing, and reserved chrome height for UI text.
--- @param window_w number
--- @param window_h number
--- @return table layout
function M.from_window(window_w, window_h)
	local n = config.BOARD_SIZE
	local chrome = 72
	local margin = config.MARGIN
	local side = math.min(window_w - 2 * margin, window_h - chrome - 2 * margin)
	local span = n - 1
	local cell = side / span
	local ox = (window_w - span * cell) / 2
	local oy = margin + (window_h - chrome - span * cell - 2 * margin) / 2
	return {
		cell = cell,
		ox = ox,
		oy = oy,
		n = n,
		chrome_y = window_h - chrome + 8,
	}
end

--- Converts grid coordinates to the pixel center of that intersection.
--- @param layout table
--- @param row integer
--- @param col integer
--- @return number px
--- @return number py
function M.grid_to_pixel(layout, row, col)
	local px = layout.ox + (col - 1) * layout.cell
	local py = layout.oy + (row - 1) * layout.cell
	return px, py
end

--- Finds the nearest intersection to a pixel point within hit radius.
--- @param layout table
--- @param px number
--- @param py number
--- @return integer|nil row
--- @return integer|nil col
function M.pixel_to_grid(layout, px, py)
	local n = layout.n
	local best_r, best_c = nil, nil
	local best_d = (layout.cell * 0.55) ^ 2
	for r = 1, n do
		for c = 1, n do
			local gx, gy = M.grid_to_pixel(layout, r, c)
			local dx = px - gx
			local dy = py - gy
			local d = dx * dx + dy * dy
			if d <= best_d then
				best_d = d
				best_r, best_c = r, c
			end
		end
	end
	return best_r, best_c
end

return M
