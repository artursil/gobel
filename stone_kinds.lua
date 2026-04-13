--- Registry of stone kinds and pluggable per-kind data (scoring, future rules).

local M = {}

M.NORMAL = 1
M.X = 2

local defs = {
	[M.NORMAL] = {
		liberty_score_multiplier = 1,
	},
	[M.X] = {
		liberty_score_multiplier = 5,
	},
}

--- Weight applied to each unique liberty contributed via stones of this kind.
--- @param kind integer
--- @return number
function M.liberty_score_multiplier(kind)
	local d = defs[kind]
	if not d then
		return 1
	end
	return d.liberty_score_multiplier
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
