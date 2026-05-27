--- Pixel quads for ``sprites/stones/stones.png`` deterioration frames.
---
--- **Manual** (preferred): set ``frames.white`` / ``frames.black`` — one ``{ x, y, w, h }`` per tier
--- (tier 0 = leftmost / perfect, tier 3 = rightmost / worst). Measure in an image editor.
---
--- **Grid fallback**: when ``frames`` is omitted, ``ui.stone_solidity_atlas`` splits the PNG into a
--- 2×``cols`` grid using image width/height and ``inset``. Per-tier manual rects that fall outside
--- the image also fall back to the grid for that tier only.
---
--- @module objects.parameters.stone_solidity_atlas

return {
	path = "sprites/stones/stones.png",

	frames = {
		white = {
			{ x = 40, y = 112, w = 308, h = 318 },
			{ x = 400, y = 112, w = 308, h = 318 },
			{ x = 765, y = 112, w = 308, h = 318 },
			{ x = 1132, y = 112, w = 308, h = 318 },
		},
		black = {
			{ x = 40, y = 526, w = 308, h = 318 },
			{ x = 400, y = 526, w = 308, h = 318 },
			{ x = 765, y = 526, w = 308, h = 318 },
			{ x = 1132, y = 526, w = 308, h = 318 },
		},
	},

	cols = 4,
	row_white = 0,
	row_black = 1,
	inset = 2,
}
