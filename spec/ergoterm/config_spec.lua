---@diagnostic disable: undefined-field

local config = require("ergoterm.config")

describe("config.get", function()
  it("returns the full config when called without arguments", function()
    local conf = config.get()

    assert.is_table(conf)
    assert.is_not_nil(conf.layout)
  end)

  it("returns a specific config value when key is provided", function()
    assert.equal(config.get("layout"), "below")
  end)
end)

describe("config.set", function()
  it("overrides config values with user config", function()
    local old_layout = config.get("layout")

    ---@diagnostic disable: missing-fields
    config.set({ layout = "left", auto_scroll = false })

    assert.equal(config.get("layout"), "left")
    assert.is_false(config.get("auto_scroll"))

    config.set({ layout = old_layout, auto_scroll = true })
  end)

  it("merges deeply into nested tables", function()
    ---@diagnostic disable: missing-fields
    config.set({ float_opts = { width = 123 } })

    assert.equal(config.get("float_opts").width, 123)
  end)
end)
