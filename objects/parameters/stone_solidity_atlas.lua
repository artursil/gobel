--- Pixel quads for ``sprites/stones/stones.png`` deterioration frames.
---
--- **Layout**: row 1 = white stones, row 2 = black stones; left → right = perfect (tier 0) → worst (tier 3).
--- Frames have uneven padding — update ``x,y,w,h`` when the atlas art changes (measure in an image editor).
---
--- **Calibration** (placeholder bounds; replace with measured values from the shipped PNG):
--- - White row: ``y ≈ 6``, frame tops aligned; black row: ``y ≈ 206``.
--- - Frame widths differ slightly (~172–180px); gaps ~22px between frames.
--- @module objects.parameters.stone_solidity_atlas

return {
	path = "sprites/stones/stones.png",
	frames = {
		white = {
			{ x = 8, y = 6, w = 180, h = 180 },
			{ x = 210, y = 6, w = 175, h = 180 },
			{ x = 408, y = 6, w = 178, h = 180 },
			{ x = 610, y = 6, w = 172, h = 180 },
		},
		black = {
			{ x = 8, y = 206, w = 180, h = 180 },
			{ x = 210, y = 206, w = 175, h = 180 },
			{ x = 408, y = 206, w = 178, h = 180 },
			{ x = 610, y = 206, w = 172, h = 180 },
		},
	},
}
