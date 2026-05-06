--- DEPRECATED COMPATIBILITY SHIM: poses module.
--- All logic moved to stances module.
--- This file maintained temporarily for PR 1 compatibility.
--- REMOVAL PLAN: Delete after PR 2 completes and all references updated.
--- @module poses

local stances = require("stances")

return stances
