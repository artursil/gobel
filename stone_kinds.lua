--- Registry of stone kinds: visuals, incoming RNG, and scoring constants.

local M = {}

M.NORMAL = 1
M.X = 2

--- Added to overall multiplier for each qualifying diagonal cross (five same-color stones; at least one X-kind).
M.MULT_BONUS_PER_DIAGONAL_X_PATTERN = 3

--- Chooses the next stone kind for the incoming pipeline (extend with weights or pools later).
--- @return integer
function M.random_incoming()
	if love.math.random() < 0.18 then
		return M.X
	end
	return M.NORMAL
end

return M
