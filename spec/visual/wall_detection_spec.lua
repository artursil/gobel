local helper = require("spec.spec_helper")
local enclosure = require("single_game.resolver.enclosure")
local config = require("config")

local function walls_ascii(n, wall)
	local boundary = {}
	for i = 1, #(wall.boundary_fields or {}) do
		local p = wall.boundary_fields[i]
		boundary[p[1] * 100 + p[2]] = true
	end
	local inside = {}
	for i = 1, #(wall.inside_fields or {}) do
		local p = wall.inside_fields[i]
		inside[p[1] * 100 + p[2]] = true
	end
	local boundary_mark = wall.owner == "B" and "B" or "W"
	local inside_mark = wall.owner == "B" and "b" or "w"

	local lines = {}
	for r = 1, n do
		local row = {}
		for c = 1, n do
			local key = r * 100 + c
			if boundary[key] then
				row[#row + 1] = boundary_mark
			elseif inside[key] then
				row[#row + 1] = inside_mark
			else
				row[#row + 1] = "."
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

local function wall_size(wall)
	return #(wall.inside_fields or {}) + #(wall.boundary_fields or {})
end

local function biggest_wall(walls)
	local best = walls[1]
	for i = 2, #walls do
		if wall_size(walls[i]) > wall_size(best) then
			best = walls[i]
		end
	end
	return best
end

local function debug_dump_all_walls(name, b, walls)
	if not helper.integration_debug_enabled() then
		return
	end
	print("[INTEGRATION_DEBUG] " .. name .. " found walls: " .. tostring(#walls))
	for i = 1, #walls do
		local wall = walls[i]
		print("[INTEGRATION_DEBUG] wall #" .. tostring(i)
			.. " owner=" .. tostring(wall.owner)
			.. " boundary=" .. tostring(#(wall.boundary_fields or {}))
			.. " inside=" .. tostring(#(wall.inside_fields or {})))
		print(walls_ascii(config.BOARD_SIZE, wall))
	end
end

describe("Wall detection", function()
	it("extracts and renders biggest wall from sample board", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W W . . . .",
			". . W . . W . . .",
			". . W . . W . . .",
			". . . W . W . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(type(walls) == "table")
		assert.is_true(#walls > 0)
		debug_dump_all_walls("biggest_wall", b, walls)

		local actual = walls_ascii(config.BOARD_SIZE, biggest_wall(walls))
		assert.are.equal(table.concat({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W W . . . .",
			". . W w w W . . .",
			". . W w w W . . .",
			". . . W w W . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n"), actual)
	end)

	it("extracts biggest wall: white triangle top-left", function()
		local b = helper.parse_board_ascii({
			". . . B . . . W .",
			"B B B B . . W . .",
			". . . . . W . . .",
			"W W W W W . . . .",
			". . . W . . . . .",
			"W W W . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(#walls > 0)
		debug_dump_all_walls("biggest_wall", b, walls)

		assert.are.equal(table.concat({
			"w w w w w w w W .",
			"w w w w w w W . .",
			"w w w w w W . . .",
			"W W W W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n"), walls_ascii(config.BOARD_SIZE, biggest_wall(walls)))
	end)

	it("extracts biggest wall: white with extra column", function()
		local b = helper.parse_board_ascii({
			". . . B . . . W .",
			"B B B B . . W . .",
			". . . . . W W . .",
			"W W W W W W W . .",
			". . . W . W . . .",
			"W W W . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(#walls > 0)
		debug_dump_all_walls("biggest_wall", b, walls)

		assert.are.equal(table.concat({
			"w w w w w w w W .",
			"w w w w w w W . .",
			"w w w w w W W . .",
			"W W W W W W . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n"), walls_ascii(config.BOARD_SIZE, biggest_wall(walls)))
	end)

	it("extracts biggest wall: white simple triangle", function()
		local b = helper.parse_board_ascii({
			". . . B . . . W .",
			"B B B B . . W . .",
			". . . . . W . . .",
			"W W W W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(#walls > 0)
		debug_dump_all_walls("biggest_wall", b, walls)

		assert.are.equal(table.concat({
			"w w w w w w w W .",
			"w w w w w w W . .",
			"w w w w w W . . .",
			"W W W W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n"), walls_ascii(config.BOARD_SIZE, biggest_wall(walls)))
	end)

	it("extracts smallest wall: black cap", function()
		local b = helper.parse_board_ascii({
			". . . B . . . W .",
			"B B B B . . W . .",
			". . . . . W . . .",
			"W W W W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(#walls > 0)
		debug_dump_all_walls("smallest_wall", b, walls)

		assert.are.equal(table.concat({
			"b b b B . . . . .",
			"B B B B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n"), walls_ascii(config.BOARD_SIZE, walls[1]))
	end)

	it("renders inside including enclosed stones: black ring", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . B B B . . . .",
			". . B W B . . . .",
			". . B . B . . . .",
			". . B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(#walls > 0)
		debug_dump_all_walls("inside_includes_stones", b, walls)

		assert.are.equal(table.concat({
			". . . . . . . . .",
			". . B B B . . . .",
			". . B b B . . . .",
			". . B b B . . . .",
			". . B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n"), walls_ascii(config.BOARD_SIZE, biggest_wall(walls)))
	end)

	it("renders inside including enclosed stones: mixed corner ring", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W B B . . .",
			". . . B . B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(#walls > 0)
		debug_dump_all_walls("inside_includes_stones", b, walls)

		assert.are.equal(table.concat({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . B B . . .",
			". . . B b B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n"), walls_ascii(config.BOARD_SIZE, biggest_wall(walls)))
	end)

	it("renders inside including enclosed stones: tall black column", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B . . . . .",
			"W W W W B . . . .",
			". B . . W B . . .",
			"B . . . W B . . .",
			". B B B W B . . .",
			". B . B W B . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(#walls > 0)
		debug_dump_all_walls("inside_includes_stones", b, walls)

		assert.are.equal(table.concat({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"b b b b B . . . .",
			"b b b b b B . . .",
			"b b b b b B . . .",
			"b b b b b B . . .",
			"b b b b b B . . .",
		}, "\n"), walls_ascii(config.BOARD_SIZE, biggest_wall(walls)))
	end)
end)
