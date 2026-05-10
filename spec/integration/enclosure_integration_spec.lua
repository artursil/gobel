local helper = require("spec.spec_helper")
local enclosure = require("single_game.resolver.enclosure")

local function assert_expected_ownership_ascii(b, regions, tiles, expected_rows)
	assert.are.equal(table.concat(expected_rows, "\n"), helper.regions_ascii(b, regions, tiles))
end

describe("Enclosure integration (detect_regions_and_ownership)", function()
	it("claims a fully enclosed center point for black", function()
		local b = require("board").new()
		local config = require("config")
		for r = 4, 6 do
			for c = 4, 6 do
				if not (r == 5 and c == 5) then
					b[r][c] = require("board").make_stone(config.STONE_BLACK, "stone_basic")
				end
			end
		end

		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("black_center_enclosure", b, regions, tiles)

		local enclosed_region_count = 0
		for _, region in pairs(regions) do
			if region.owner == "B" then
				enclosed_region_count = enclosed_region_count + 1
			end
		end

		assert.is_true(enclosed_region_count >= 1)
		local center_region_id = tiles[5][5].region_id
		assert.is_true(center_region_id ~= nil)
		assert.are.equal("B", regions[center_region_id].owner)
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B b B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("does not claim center when enclosure boundary is mixed", function()
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
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("mixed_boundary_center", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W B B . . .",
			". . . B b B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps edge-connected region unowned by enclosure", function()
		local b = helper.parse_board_ascii({
			". . . B . . . . .",
			". B B B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("edge_connected_region", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . B . . . . .",
			". B B B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps board fixture #1 center region unowned", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . W W . . . . .",
			". . W B W W . . .",
			". . . W . W . . .",
			". . . W W W . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_1", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . W W . . . . .",
			". . W B W W . . .",
			". . . W w W . . .",
			". . . W W W . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps board fixture #2 sampled empty region unowned", function()
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
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_2", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			"b b b B w w w W .",
			"B B B B w w W . .",
			"w w w w w W . . .",
			"W W W W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps board fixture #3 sampled empty region unowned", function()
		local b = helper.parse_board_ascii({
			". . . . . . . W .",
			"B B B B . . W . .",
			". . . . . W . . .",
			"W W W W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_3", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			"w w w w w w w W .",
			"B B B B w w W . .",
			"w w w w w W . . .",
			"W W W W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps board fixture #4 sampled empty region unowned", function()
		local b = helper.parse_board_ascii({
			". . . B . . . W .",
			"B B B B . . W . .",
			". . . . . W . . B",
			"W W W W W . . B .",
			". . . . . . B . .",
			". . . . . B . . .",
			". . . . . B . . .",
			". . . . . B . . .",
			". . . . . B . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_4", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			"b b b B w w w W .",
			"B B B B w w W . .",
			"w w w w w W . . B",
			"W W W W W . . B b",
			". . . . . . B b b",
			". . . . . B b b b",
			". . . . . B b b b",
			". . . . . B b b b",
			". . . . . B b b b",
		})
	end)

	it("keeps board fixture #5 sampled empty region unowned", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . B . . . . .",
			"W W W . . . . . .",
			". B . W . . . . .",
			". B B W . . . . .",
			". . . W . . . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_5", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . B . . . . .",
			"W W W . . . . . .",
			"w B w W . . . . .",
			"w B B W . . . . .",
			"w w w W . . . . .",
		})
	end)

	it("keeps board fixture #6 sampled empty region unowned", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			". B B B . . . . .",
			"W W W W B . . . .",
			". B . . W B . . .",
			". . . . W B . . .",
			". . . . W B . . .",
			". . . . W B . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_6", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			". B B B . . . . .",
			"W W W W B . . . .",
			"w B w w W B . . .",
			"w w w w W B . . .",
			"w w w w W B . . .",
			"w w w w W B . . .",
		})
	end)

	it("keeps board fixture #7 sampled empty region unowned", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			". B B B . . . . .",
			"W W W W B . . . .",
			". B . . W B . . .",
			". . B . W B . . .",
			". . . B W B . . .",
			". . . . W B . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_7", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			". B B B . . . . .",
			"W W W W B . . . .",
			"w B w w W B . . .",
			"w w B w W B . . .",
			"w w w B W B . . .",
			"w w w w W B . . .",
		})
	end)

	it("keeps board fixture #8 sampled empty region unowned", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B . . . . .",
			"W W W W B . . . .",
			". B . . W B . . .",
			". . . . W B . . .",
			". . . . W B . . .",
			". . . . W B . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_8", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B . . . . .",
			"W W W W B . . . .",
			"w B w w W B . . .",
			"w w w w W B . . .",
			"w w w w W B . . .",
			"w w w w W B . . .",
		})
	end)

	it("keeps board fixture #9 sampled empty region unowned", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B . . . . .",
			"W B W W B . . . .",
			". B . . W B . . .",
			". . . . W B . . .",
			". . . . W B . . .",
			". . . . W B . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_9", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B . . . . .",
			"W B W W B . . . .",
			"b B b b W B . . .",
			"b b b b W B . . .",
			"b b b b W B . . .",
			"b b b b W B . . .",
		})
	end)

	it("keeps board fixture #95 sampled empty region unowned", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B B B . . .",
			"W B W W . B . . .",
			". B . . W B . . .",
			". . . . W B . . .",
			". . . . W B . . .",
			". . . . W B . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture_95", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B B B . . .",
			"W B W W b B . . .",
			"b B b b W B . . .",
			"b b b b W B . . .",
			"b b b b W B . . .",
			"b b b b W B . . .",
		})
	end)

	it("keeps board fixture #10 sampled empty region unowned", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B . . . . .",
			"W B W W B . . . .",
			". B . . W B . . .",
			". . . . W B . . .",
			". B B B W B . . .",
			". B . B W B . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture10", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B . . . . .",
			"W B W W B . . . .",
			"b B b b W B . . .",
			"b b b b W B . . .",
			"b B B B W B . . .",
			"b B b B W B . . .",
		})
	end)

	it("keeps board fixture #11 sampled empty region unowned", function()
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
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture1q", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B . . . . .",
			"W W W W B . . . .",
			"w B w w W B . . .",
			"B w w w W B . . .",
			"b B B B W B . . .",
			"b B b B W B . . .",
		})
	end)

	it("keeps board fixture #12 complex mix", function()
		local b = helper.parse_board_ascii({
			"W . B . W . . . .",
			"B W . W . W . . .",
			"B B W . B B W . .",
			"B . B . . W . W .",
			"W . B . . B . . W",
			"B W W B B . . W .",
			". . B W B B W . .",
			"B B . W W W . W B",
			". B B . W . . B .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture1q", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			"W w B w W w w w w",
			"B W w W . W w w w",
			"B B W . B B W w w",
			"B b B . . W . W w",
			"W b B . . B . . W",
			"B W W B B . . W w",
			". . B W B B W w w",
			"B B w W W W w W B",
			"b B B w W w w B b",
		})
	end)

	it("keeps board fixture #13 enclosures with gaps", function()
		local b = helper.parse_board_ascii({
			". . . W . . W . .",
			". B . W . . W . .",
			"B . W B B B W . .",
			". W B W . W B W B",
			". W B . W . B W .",
			". . W B B B . W .",
			". B . W . . . W .",
			"W W W . . . . . W",
			". . . . . . . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture1q", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			"w w w W w w W w w",
			"w B w W w w W w w",
			"B w W B B B W w w",
			"w W B W . W B W B",
			"w W B b W b B W w",
			"w w W B B B . W w",
			"w B w W . . . W w",
			"W W W . . . . . W",
			". . . . . . . . .",
		})
	end)

	it("keeps board fixture #14 diagonal enclosure", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			"B B . . . . . . .",
			". . B . . . . . .",
			"W . B . . . . . .",
			". W W B . . . . .",
			". . B W . . . . .",
			"B B . W W . . . .",
			". . . . W . . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture1q", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			"B B . . . . . . .",
			"b b B . . . . . .",
			"W b B . . . . . .",
			". W W B . . . . .",
			". . B W . . . . .",
			"B B w W W . . . .",
			"w w w w W . . . .",
		})
	end)

	it("keeps board fixture #15 interleaved colors", function()
		local b = helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			". W . B . . . . .",
			"B . W B . . . . .",
			". W . . . . . . .",
			"W . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture1q", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			"w W . B . . . . .",
			"B w W B . . . . .",
			"w W . . . . . . .",
			"W . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)
end)
