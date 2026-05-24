--- Cached LÖVE images; prefers ``*_r.png`` for resized card/stance/frame assets only.
--- @module ui.sprites

local M = {}

local cache = {}

--- Card/stance resized assets use ``*_r.png``; stone/board sprites use the exact path given.
--- @param path string
--- @return string[]
local function candidate_paths(path)
	if path:match("_r%.png$") then
		return { path }
	end
	if path:find("/stones/", 1, true) or path:find("\\stones\\", 1, true) then
		return { path }
	end
	local resized = path:gsub("%.png$", "_r.png")
	if resized ~= path then
		return { resized, path }
	end
	return { path }
end

--- @param path string
--- @return love.graphics.Image|false
--- @return string|nil error_message when load failed but path may exist
function M.get_image(path)
	if type(path) ~= "string" or path == "" then
		return false, "empty path"
	end
	if cache[path] ~= nil then
		if cache[path] == false then
			return false, cache[path .. ":err"]
		end
		return cache[path], nil
	end
	local last_err = nil
	for _, candidate in ipairs(candidate_paths(path)) do
		local ok, image = pcall(love.graphics.newImage, candidate)
		if ok and image then
			cache[path] = image
			return image, nil
		end
		if not ok then
			last_err = image
		end
	end
	cache[path] = false
	if last_err then
		cache[path .. ":err"] = tostring(last_err)
	end
	return false, last_err and tostring(last_err) or "not found"
end

--- @param path string|nil when nil, clears entire cache
--- @return nil
function M.clear_cache(path)
	if path then
		cache[path] = nil
		cache[path .. ":err"] = nil
		return
	end
	for key in pairs(cache) do
		cache[key] = nil
	end
end

return M
