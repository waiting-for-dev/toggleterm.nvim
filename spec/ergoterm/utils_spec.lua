---@diagnostic disable: undefined-field

local utils = require("ergoterm.utils")

describe(".notify", function()
  it("notifies with correct message, uppercased level, and title", function()
    local original_schedule = vim.schedule
    local original_notify = vim.notify
    vim.notify = function(...) end
    vim.schedule = function(fn) fn() end
    spy.on(vim, "notify")
    spy.on(vim, "schedule")

    utils.notify("hello", "info")

    assert.spy(vim.schedule).was_called()
    assert.spy(vim.notify).was_called_with("hello", vim.log.levels.INFO, { title = "Ergoterm" })

    vim.schedule = original_schedule
    vim.notify = original_notify
  end)
end)
