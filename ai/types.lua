--- Documented shapes for AI actions, features, and search (no runtime logic).
--- @module ai.types

--- @class AiAction
--- @field actor "black"|"white"
--- @field type "PLAY_CARD"|"SELECT_STONE"|"SELECT_BOARD_TARGET"|"PLACE_STONE"|"PASS_TURN"
--- @field payload table

--- @class AiBoardFeatures
--- @field territory_owned_me integer
--- @field territory_owned_opp integer
--- @field territory_contested integer empty cells with meaningful influence from both sides
--- @field wall_count_me integer
--- @field largest_enclosure_inside_me integer
--- @field weak_boundary_cells integer
--- @field connectivity_score_me number

--- @class AiMoveCandidateFeatures
--- @field row integer
--- @field col integer
--- @field delta_territory_me integer
--- @field delta_captures integer
--- @field delta_enclosure_inside integer
--- @field closes_region boolean
--- @field score number

--- @class AiGoal
--- @field id string
--- @field weight number
--- @field active boolean

return {}
