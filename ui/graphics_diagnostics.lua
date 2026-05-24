--- One-shot startup checks for renderer and critical assets (console output).
--- @module ui.graphics_diagnostics

local atlas_params = require("objects.parameters.stone_solidity_atlas")
local sprites = require("ui.sprites")
local stone_solidity_atlas = require("ui.stone_solidity_atlas")

local M = {}

local reported = false

--- @param path string
--- @return nil
local function report_atlas_path(path)
	sprites.clear_cache(path)
	local info = love.filesystem.getInfo(path)
	if not info then
		print("[gobel] LÖVE does not see file: " .. path)
		if love.filesystem.getSourceBaseDirectory then
			print("[gobel] Game source: " .. tostring(love.filesystem.getSourceBaseDirectory()))
		end
		print("[gobel] Run `love .` from the repo root (folder containing main.lua).")
		return
	end
	local img, err = sprites.get_image(path)
	if not img then
		print("[gobel] Found on disk but failed to load: " .. path)
		if err then
			print("[gobel]   " .. tostring(err))
		end
		return
	end
	stone_solidity_atlas.reset_for_tests()
	if stone_solidity_atlas.is_available() then
		print("[gobel] Solidity atlas loaded: " .. path)
	else
		local w, h = img:getWidth(), img:getHeight()
		print(
			string.format(
				"[gobel] Loaded %s (%dx%d) but quads are out of bounds — update objects/parameters/stone_solidity_atlas.lua",
				path,
				w,
				h
			)
		)
	end
end

--- @return nil
function M.report_startup()
	if reported then
		return
	end
	reported = true

	if not love or not love.graphics then
		print("[gobel] love.graphics unavailable")
		return
	end

	if love.graphics.isCreated and not love.graphics.isCreated() then
		print("[gobel] Graphics context not created — Mesa/ZINK errors usually mean nothing will draw.")
		print("[gobel] WSL: try Windows love.exe, or: LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe love .")
		return
	end

	if love.graphics.getRendererInfo then
		local name, version, vendor = love.graphics.getRendererInfo()
		print(string.format("[gobel] Renderer: %s (%s) — %s", tostring(name), tostring(version), tostring(vendor)))
	end

	report_atlas_path(atlas_params.path)
end

return M
