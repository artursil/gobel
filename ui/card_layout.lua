--- Shared playing-card face layout (hand + selected): art, title, description regions.
--- @module ui.card_layout

local M = {}

M.ART_HEIGHT_FRAC = 0.55

--- @param inner_w number
--- @param inner_h number
--- @return table
function M.face_regions(inner_w, inner_h)
	local pad = math.max(5, math.floor(inner_w * 0.045))
	local energy_r = math.max(10, math.min(15, math.floor(inner_w * 0.095)))
	local energy_cx = pad + energy_r
	local energy_cy = pad + energy_r
	local title_h = math.max(16, math.floor(inner_h * 0.1))
	local desc_h = math.max(18, math.floor(inner_h * 0.17))
	local gap = 3
	local desc_y = inner_h - pad - desc_h
	local title_y = desc_y - gap - title_h
	local art_y = pad
	local art_bottom = title_y - gap
	local art_h = math.max(12, math.min(math.floor(inner_h * M.ART_HEIGHT_FRAC), art_bottom - art_y))
	return {
		pad = pad,
		energy_r = energy_r,
		energy_cx = energy_cx,
		energy_cy = energy_cy,
		art_x = pad,
		art_y = art_y,
		art_w = inner_w - pad * 2,
		art_h = art_h,
		title_x = pad,
		title_y = title_y,
		title_w = inner_w - pad * 2,
		title_h = title_h,
		desc_x = pad,
		desc_y = desc_y,
		desc_w = inner_w - pad * 2,
		desc_h = desc_h,
	}
end

return M
