require("spec.test_helper")

local number_format = require("ui.number_format")

describe("ui.number_format", function()
	it("format_integer below 1e9 stays decimal", function()
		assert.are.equal("999999999", number_format.format_integer(999999999))
		assert.are.equal("43", number_format.format_integer(42.2))
	end)

	it("format_integer at 1e9 and above uses scientific notation", function()
		assert.are.equal("1.00e+09", number_format.format_integer(1e9))
		assert.are.equal("1.50e+10", number_format.format_integer(1.5e10))
	end)

	it("format_decimal below 1e9 keeps fixed decimals", function()
		assert.are.equal("1.1", number_format.format_decimal(1.1, 1))
	end)

	it("format_decimal at 1e9 and above uses scientific notation", function()
		assert.are.equal("1.0e+09", number_format.format_decimal(1e9, 1))
	end)
end)
