--- Cached LÖVE images; prefers ``*_r.png`` for resized card/stance/frame assets.
--- @module ui.sprites

local M = {}

local cache = {}

--- @param path string
--- @return love.graphics.Image|false
function M.get_image(path)
	if type(path) ~= "string" or path == "" then
		return false
	end
	if cache[path] ~= nil then
		return cache[path]
	end
	local candidates = {}
	if path:match("_r%.png$") then
		candidates[1] = path
	else
		candidates[1] = path:gsub("%.png$", "_r.png")
		candidates[2] = path
	end
	for i = 1, #candidates do
		local candidate = candidates[i]
		if candidate ~= path or i == 1 then
			local ok, image = pcall(love.graphics.newImage, candidate)
			if ok and image then
				cache[path] = image
				return image
			end
		end
	end
	if candidates[1] ~= path then
		local ok, image = pcall(love.graphics.newImage, path)
		if ok and image then
			cache[path] = image
			return image
		end
	end
	cache[path] = false
	return false
end

return M
