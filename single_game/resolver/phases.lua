--- Scoring phase constants (macro lifecycle + sub pass order).
--- @module resolver.phases

local scoring_phases = require("single_game.resolver.scoring_phases")

local M = {}

M.SUB_ORDER = scoring_phases.SUB_ORDER
M.TERRITORY_STEP_DISTANCE = scoring_phases.TERRITORY_STEP_DISTANCE
M.TERRITORY_STEP_VALUE = scoring_phases.TERRITORY_STEP_VALUE
M.TERRITORY_STEP_OVERRIDE = scoring_phases.TERRITORY_STEP_OVERRIDE

return M
