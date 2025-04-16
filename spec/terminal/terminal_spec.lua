---@diagnostic disable: undefined-field

local terms = require("ergoterm.terminal")
local utils = require("ergoterm.utils")

local function mocking_notify(callback)
  local result = nil
  local original_notify = utils.notify
  ---@diagnostic disable-next-line: duplicate-set-field
  utils.notify = function(msg, level)
    result = {
      msg = msg,
      level = level
    }
  end
  callback()
  utils.notify = original_notify
  return result
end

after_each(function()
  terms.delete_all()
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
    assert.is_false(vim.tbl_contains(result, term2))
  end)

  it("returns empty table when no terminals exist", function()
    local result = terms.get_started()

    assert.equal(0, #result)
  end)
end)

describe("get", function()
  it("returns terminal with given id", function()
    local term = terms.Terminal:new()

    assert.equal(
      term,
      terms.get(term.id)
    )
  end)

  it("returns nil when terminal does not exist", function()
    assert.is_nil(terms.get(1))
  end)
end)

describe("get_by_name", function()
  it("returns terminal with given name", function()
    local term = terms.Terminal:new({ name = "test" })

    assert.equal(
      term,
      terms.get_by_name("test")
    )
  end)

  it("returns nil when terminal does not exist", function()
    assert.is_nil(terms.get_by_name("foo"))
  end)
end)

describe("find", function()
  it("returns terminal matching given predicate", function()
    local term = terms.Terminal:new({ name = "test" })
    terms.Terminal:new({ name = "foo" })

    local result = terms.find(function(t)
      return t.name == "test"
    end)

    assert.equal(result, term)
  end)

  it("returns nil when no terminal matches predicate", function()
    terms.Terminal:new({ name = "foo" })

    local result = terms.find(function(t)
      return t.name == "bar"
    end)

    assert.is_nil(result)
  end)
end)

describe("select", function()
  it("returns result of calling given picker with started terminal and given prompt and callbacks", function()
    local picker = {
      select = function(terminals, prompt, callbacks)
        return { terminals, prompt, callbacks }
      end
    }
    local term = terms.Terminal:new():start()
    terms.Terminal:new()
    local callbacks = {}

    local result = terms.select(picker, "prompt", callbacks)

    ---@diagnostic disable: need-check-nil
    assert.equal(1, #result[1])
    assert.is_true(vim.tbl_contains(result[1], term))
    assert.equal("prompt", result[2])
    assert.equal(callbacks, result[3])
    ---@diagnostic enable: need-check-nil
  end)

  it("notifies when no terminals are started", function()
    local picker = {
      select = function()
        return nil
      end
    }
    local result = mocking_notify(function()
      terms.select(picker, "prompt", {})
    end)

    ---@diagnostic disable: need-check-nil
    assert.equal("No ergoterms have been started yet", result.msg)
    assert.equal("info", result.level)
    ---@diagnostic enable: need-check-nil
  end)
end)
