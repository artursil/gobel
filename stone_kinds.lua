--- Registry of stone kinds: visuals, incoming RNG, and scoring hooks (mult bonus, future rules).

local M = {}

M.NORMAL = 1
M.X = 2

local defs = {
	[M.NORMAL] = {
		overall_mult_bonus = 0,
	},
	[M.X] = {
		overall_mult_bonus = 3,
	},
}

--- Bonus added to the player's overall score multiplier per stone of this kind on the board.
--- @param kind integer
--- @return integer
function M.overall_mult_bonus_for_kind(kind)
	local d = defs[kind]
	if not d then
		return 0
	end
	return d.overall_mult_bonus
end

--- Chooses the next stone kind for the incoming pipeline (extend with weights or pools later).
--- @return integer
function M.random_incoming()
	if love.math.random() < 0.18 then
		return M.X
	end
	return M.NORMAL
end

return M
