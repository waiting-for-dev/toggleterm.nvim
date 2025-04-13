---@diagnostic disable: undefined-field

local terms = require("ergoterm.terminal")

after_each(function()
  terms.shutdown_all()
end)

describe("get_focused", function()
  it("returns currently focused terminal", function()
    local term = terms.Terminal:new()
    term:focus()

    local result = terms.get_focused()

    assert.equal(result, term)
  end)

  it("returns nil when there are terminals but none are focused", function()
    local term = terms.Terminal:new()
    term:focus()
    term:close()

    assert.is_nil(
      terms.get_focused()
    )
  end)

  it("returns nil when no terminals exist", function()
    assert.is_nil(
      terms.get_focused()
    )
  end)
end)

describe("get_last_focused", function()
  it("returns last focused terminal", function()
    local term = terms.Terminal:new()
    term:focus()
    term:close()

    assert.equal(
      terms.get_last_focused(),
      term
    )
  end)

  it("returns currently focused terminal", function()
    local term = terms.Terminal:new()
    term:focus()

    local result = terms.get_last_focused()

    assert.equal(result, term)
  end)

  it("returns nil when no terminals exist", function()
    assert.is_nil(
      terms.get_last_focused()
    )
  end)
end)
