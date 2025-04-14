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

describe("get_all", function()
  it("returns all terminals", function()
    local term1 = terms.Terminal:new()
    local term2 = terms.Terminal:new()

    local result = terms.get_all()

    assert.equal(2, #result)
    assert.is_true(vim.tbl_contains(result, term1))
    assert.is_true(vim.tbl_contains(result, term2))
  end)

  it("returns empty table when no terminals exist", function()
    local result = terms.get_all()

    assert.equal(0, #result)
  end)
end)

describe("get_started", function()
  it("returns all started terminals", function()
    local term1 = terms.Terminal:new():start()
    local term2 = terms.Terminal:new()

    local result = terms.get_started()

    assert.equal(1, #result)
    assert.is_true(vim.tbl_contains(result, term1))
  end)

  it("returns empty table when no terminals exist", function()
    local result = terms.get_started()

    assert.equal(0, #result)
  end)
end)
