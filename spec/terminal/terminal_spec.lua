---@diagnostic disable: undefined-field

local terms = require("ergoterm.terminal")

local config = require("ergoterm.config")
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
  terms.reset_ids()
end)

describe(".get_focused", function()
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

describe(".get_last_focused", function()
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

describe(".get_all", function()
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

describe(".get_started", function()
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

describe(".get", function()
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

describe(".get_by_name", function()
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

describe(".find", function()
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

describe(".select", function()
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

describe(".delete_all", function()
  it("deletes all terminals", function()
    local term = terms.Terminal:new()

    terms.delete_all()

    assert.is_nil(terms.get(term.id))
  end)

  it("stops any running terminals", function()
    local term = terms.Terminal:new():start()

    terms.delete_all()

    assert.is_nil(terms.get(term.id))
  end)
end)

describe(".get_state", function()
  it("returns value for a given key from the state", function()
    local term = terms.Terminal:new({ foo = "bar" })

    assert.is_true(vim.tbl_contains(terms.get_state("terminals"), term))
  end)
end)

describe(".reset_ids", function()
  it("resets sequence of terminal ids", function()
    local term1 = terms.Terminal:new()
    term1:delete()

    terms.reset_ids()
    local term2 = terms.Terminal:new()

    assert.equal(1, term2.id)
  end)
end)

describe(":new", function()
  it("takes auto_scroll option", function()
    local term = terms.Terminal:new({ auto_scroll = false })

    assert.is_false(term.auto_scroll)
  end)

  it("defaults to config's auto_scroll", function()
    local term = terms.Terminal:new()

    assert.is_true(term.auto_scroll)
  end)

  it("takes cmd option", function()
    local term = terms.Terminal:new({ cmd = "echo hello" })

    assert.equal("echo hello", term.cmd)
  end)

  it("defaults to config's shell if cmd is not provided", function()
    local term = terms.Terminal:new()

    assert.equal(vim.o.shell, term.cmd)
  end)

  it("takes clear_env option", function()
    local term = terms.Terminal:new({ clear_env = true })

    assert.is_true(term.clear_env)
  end)

  it("defaults to config's clear_env", function()
    local term = terms.Terminal:new()

    assert.is_false(term.clear_env)
  end)

  it("takes close_on_job_exit option", function()
    local term = terms.Terminal:new({ close_on_job_exit = false })

    assert.is_false(term.close_on_job_exit)
  end)

  it("defaults to config's close_on_job_exit", function()
    local term = terms.Terminal:new()

    assert.is_true(term.close_on_job_exit)
  end)

  it("takes layout option", function()
    local term = terms.Terminal:new({ layout = "right" })

    assert.equal("right", term.layout)
  end)

  it("defaults to config's layout", function()
    local term = terms.Terminal:new()

    assert.equal("bottom", term.layout)
  end)

  it("takes env option", function()
    local term = terms.Terminal:new({ env = { FOO = "bar" } })

    assert.equal("bar", term.env.FOO)
  end)

  it("takes name option", function()
    local term = terms.Terminal:new({ name = "test" })

    assert.equal("test", term.name)
  end)

  it("defaults name to cmd option", function()
    local term = terms.Terminal:new({ cmd = "echo hello" })

    assert.equal("echo hello", term.name)
  end)

  it("takes newline_chr option", function()
    local term = terms.Terminal:new({ newline_chr = "<END>" })

    assert.equal("<END>", term.newline_chr)
  end)

  it("defaults to config's newline_chr", function()
    local term = terms.Terminal:new()

    assert.equal("\n", term.newline_chr)
  end)

  it("takes float_opts option", function()
    local term = terms.Terminal:new({ float_opts = { width = 100, height = 50 } })

    assert.equal(100, term.float_opts.width)
    assert.equal(50, term.float_opts.height)
  end)

  it("defaults to config's float_opts for non-given options", function()
    local term = terms.Terminal:new({ float_opts = { width = 100, height = 20 } })

    assert.equal("single", term.float_opts.border)
  end)

  it("defaults to config's float_opts", function()
    local term = terms.Terminal:new()

    assert.equal(80, term.float_opts.width)
    assert.equal(20, term.float_opts.height)
  end)

  it("takes float_winblend option", function()
    local term = terms.Terminal:new({ float_winblend = 20 })

    assert.equal(20, term.float_winblend)
  end)

  it("defaults to config's float_winblend", function()
    local term = terms.Terminal:new()

    assert.equal(10, term.float_winblend)
  end)

  it("takes persist_mode option", function()
    local term = terms.Terminal:new({ persist_mode = true })

    assert.is_true(term.persist_mode)
  end)

  it("defaults to config's persist_mode", function()
    local term = terms.Terminal:new()

    assert.is_false(term.persist_mode)
  end)

  it("takes start_in_insert option", function()
    local term = terms.Terminal:new({ start_in_insert = false })

    assert.is_false(term.start_in_insert)
  end)

  it("defaults to config's start_in_insert", function()
    local term = terms.Terminal:new()

    assert.is_true(term.start_in_insert)
  end)

  it("takes on_close option", function()
    local foo = nil

    local term = terms.Terminal:new({ on_close = function() foo = "foo" end })
    term:on_close()

    assert.equal("foo", foo)
  end)

  it("defaults to config's on_close", function()
    local term = terms.Terminal:new()

    assert.equal(config.NULL_CALLBACK, term.on_close)
  end)

  it("takes on_create option", function()
    local foo = nil

    local term = terms.Terminal:new({ on_create = function() foo = "foo" end })
    term:on_create()

    assert.equal("foo", foo)
  end)

  it("defaults to config's on_create", function()
    local term = terms.Terminal:new()

    assert.equal(config.NULL_CALLBACK, term.on_create)
  end)

  it("takes on_focus option", function()
    local foo = nil

    local term = terms.Terminal:new({ on_focus = function() foo = "foo" end })
    term:on_focus()

    assert.equal("foo", foo)
  end)

  it("defaults to config's on_focus", function()
    local term = terms.Terminal:new()

    assert.equal(config.NULL_CALLBACK, term.on_focus)
  end)

  it("takes on_job_exit option", function()
    local foo = nil

    local term = terms.Terminal:new({ on_job_exit = function() foo = "foo" end })
    term:on_job_exit(1, 2, "event")

    assert.equal("foo", foo)
  end)

  it("defaults to config's on_job_exit", function()
    local term = terms.Terminal:new()

    assert.equal(config.NULL_CALLBACK, term.on_job_exit)
  end)

  it("takes on_job_stdout option", function()
    local foo = nil

    local term = terms.Terminal:new({ on_job_stdout = function() foo = "foo" end })
    term:on_job_stdout(1, { "data" }, "name")

    assert.equal("foo", foo)
  end)

  it("defaults to config's on_job_stdout", function()
    local term = terms.Terminal:new()

    assert.equal(config.NULL_CALLBACK, term.on_job_stdout)
  end)

  it("takes on_job_stderr option", function()
    local foo = nil

    local term = terms.Terminal:new({ on_job_stderr = function() foo = "foo" end })
    term:on_job_stderr(1, { "data" }, "name")

    assert.equal("foo", foo)
  end)

  it("defaults to config's on_job_stderr", function()
    local term = terms.Terminal:new()

    assert.equal(config.NULL_CALLBACK, term.on_job_stderr)
  end)

  it("takes on_open option", function()
    local foo = nil

    local term = terms.Terminal:new({ on_open = function() foo = "foo" end })
    term:on_open()

    assert.equal("foo", foo)
  end)

  it("defaults to config's on_open", function()
    local term = terms.Terminal:new()

    assert.equal(config.NULL_CALLBACK, term.on_open)
  end)

  it("takes on_start option", function()
    local foo = nil

    local term = terms.Terminal:new({ on_start = function() foo = "foo" end })
    term:on_start()

    assert.equal("foo", foo)
  end)

  it("defaults to config's on_start", function()
    local term = terms.Terminal:new()

    assert.equal(config.NULL_CALLBACK, term.on_start)
  end)

  it("takes on_stop option", function()
    local foo = nil

    local term = terms.Terminal:new({ on_stop = function() foo = "foo" end })
    term:on_stop()

    assert.equal("foo", foo)
  end)

  it("defaults to config's on_stop", function()
    local term = terms.Terminal:new()

    assert.equal(config.NULL_CALLBACK, term.on_stop)
  end)

  it("builds sequential ids", function()
    local term1 = terms.Terminal:new()
    local term2 = terms.Terminal:new()

    assert.equal(1, term1.id)
    assert.equal(2, term2.id)
  end)

  it("doesn't build deleted terminal ids", function()
    local term1 = terms.Terminal:new()
    term1:delete()
    local term2 = terms.Terminal:new()

    assert.equal(2, term2.id)
  end)

  it("initializes directory as the current git directory if dir is given as 'git_dir'", function()
    local term = terms.Terminal:new({ dir = "git_dir" })

    local expected_dir = vim.fn.getcwd()

    assert.equal(expected_dir, term:get_state("dir"))
  end)

  it("initializes directory as the current working directory if dir is nil", function()
    local term = terms.Terminal:new({ dir = nil })

    local expected_dir = vim.fn.getcwd()

    assert.equal(expected_dir, term:get_state("dir"))
  end)

  it("initializes directory as the given directory if dir is a string", function()
    local term = terms.Terminal:new({ dir = "/tmp" })

    assert.equal("/tmp", term:get_state("dir"))
  end)

  it("errors if dir is not a valid directory", function()
    local result = mocking_notify(function()
      terms.Terminal:new({ dir = "/invalid" })
    end)

    ---@diagnostic disable: need-check-nil
    assert.equal("/invalid is not a directory", result.msg)
    assert.equal("error", result.level)
    ---@diagnostic enable: need-check-nil
  end)

  it("initializes layout from given layout", function()
    local term = terms.Terminal:new({ layout = "right" })

    assert.equal("right", term:get_state("layout"))
  end)

  it("doesn't override float_opts defaults for non-given options", function()
    local term = terms.Terminal:new({ float_opts = { width = 100, height = 20 } })

    assert.equal("single", term.float_opts.border)
  end)

  it("initializes float_opts title from name when not given", function()
    local term = terms.Terminal:new({ name = "test" })

    assert.equal("test", term:get_state("float_opts").title)
  end)

  it("doesn't override float_opts title when given", function()
    local term = terms.Terminal:new({ float_opts = { title = "foo" } })

    assert.equal("foo", term:get_state("float_opts").title)
  end)

  it("initializes float_opts row from height when not given", function()
    local term = terms.Terminal:new({ float_opts = { height = 20 } })

    assert.equal(math.ceil((vim.o.lines - 20)) * 0.5 - 1, term:get_state("float_opts").row)
  end)

  it("doesn't override float_opts row when given", function()
    local term = terms.Terminal:new({ float_opts = { row = 10 } })

    assert.equal(10, term:get_state("float_opts").row)
  end)

  it("initializes float_opts col from width when not given", function()
    local term = terms.Terminal:new({ float_opts = { width = 100 } })

    assert.equal(math.ceil((vim.o.columns - 100)) * 0.5 - 1, term:get_state("float_opts").col)
  end)

  it("doesn't override float_opts col when given", function()
    local term = terms.Terminal:new({ float_opts = { col = 10 } })

    assert.equal(10, term:get_state("float_opts").col)
  end)

  it("initializes on_job_exit so it calls provided on_job_exit", function()
    local foo = nil
    local term = terms.Terminal:new({ on_job_exit = function() foo = "foo" end })

    term:get_state("on_job_exit")(1, 2, "event")
    assert.equal("foo", foo)
  end)

  it("initializes on_job_stdout so it calls provided on_job_stdout", function()
    local foo = nil
    local term = terms.Terminal:new({ on_job_stdout = function() foo = "foo" end })

    term:get_state("on_job_stdout")(1, { "data" }, "name")
    assert.equal("foo", foo)
  end)

  it("initializes on_job_stderr so it calls provided on_job_stderr", function()
    local foo = nil
    local term = terms.Terminal:new({ on_job_stderr = function() foo = "foo" end })

    term:get_state("on_job_stderr")(1, { "data" }, "name")
    assert.equal("foo", foo)
  end)

  it("adds terminal to the list of terminals in the state", function()
    local term = terms.Terminal:new()

    assert.is_true(vim.tbl_contains(terms.get_state("terminals"), term))
  end)
end)

describe(":update", function()
  it("updates passed properties", function()
    local term = terms.Terminal:new({ name = "foo", layout = "bottom" })
    term:update({ name = "bar", layout = "right" })

    assert.equal("bar", term.name)
    assert.equal("right", term.layout)
  end)

  it("recomputes mode", function()
    local term = terms.Terminal:new({ start_in_insert = false })
    term:update({ start_in_insert = true })

    assert.equal("i", term:get_state("mode"))
  end)

  it("recomputes layout", function()
    local term = terms.Terminal:new({ layout = "bottom" })
    term:update({ layout = "right" })

    assert.equal("right", term:get_state("layout"))
  end)

  it("doesn't override float_opts that are not-given options", function()
    local term = terms.Terminal:new({ float_opts = { width = 100, height = 1 } })
    term:update({ float_opts = { width = 200 } })

    assert.equal(1, term:get_state("float_opts").height)
  end)

  it("recomputes on_job_exit", function()
    local foo = nil
    local term = terms.Terminal:new({ on_job_exit = function() foo = "foo" end })
    term:update({ on_job_exit = function() foo = "bar" end })

    term:get_state("on_job_exit")(1, 2, "event")
    assert.equal("bar", foo)
  end)

  it("recomputes on_job_stdout", function()
    local foo = nil
    local term = terms.Terminal:new({ on_job_stdout = function() foo = "foo" end })
    term:update({ on_job_stdout = function() foo = "bar" end })

    term:get_state("on_job_stdout")(1, { "data" }, "name")
    assert.equal("bar", foo)
  end)

  it("recomputes on_job_stderr", function()
    local foo = nil
    local term = terms.Terminal:new({ on_job_stderr = function() foo = "foo" end })
    term:update({ on_job_stderr = function() foo = "bar" end })

    term:get_state("on_job_stderr")(1, { "data" }, "name")
    assert.equal("bar", foo)
  end)

  it("doesn't allow updating cmd", function()
    local term = terms.Terminal:new({ cmd = "echo hello" })

    local result = mocking_notify(function()
      term:update({ cmd = "echo world" })
    end)

    ---@diagnostic disable: need-check-nil
    assert.equal("Cannot change cmd after terminal creation", result.msg)
    assert.equal("error", result.level)
    ---@diagnostic enable: need-check-nil
  end)

  it("doesn't allow updating dir", function()
    local term = terms.Terminal:new({ dir = "/tmp" })

    local result = mocking_notify(function()
      term:update({ dir = "/home" })
    end)

    ---@diagnostic disable: need-check-nil
    assert.equal("Cannot change dir after terminal creation", result.msg)
    assert.equal("error", result.level)
    ---@diagnostic enable: need-check-nil
  end)
end)

describe(":is_started", function()
  it("returns true if terminal is started", function()
    local term = terms.Terminal:new():start()

    assert.is_true(term:is_started())
  end)

  it("returns false if terminal is not started", function()
    local term = terms.Terminal:new()

    assert.is_false(term:is_started())
  end)
end)

describe(":start", function()
  it("creates a new buffer", function()
    local term = terms.Terminal:new()

    term:start()

    local bufnr = term:get_state("bufnr")
    assert.is_not_nil(bufnr)
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
  end)

  it("opens term with the given command", function()
    local term = terms.Terminal:new({ cmd = "echo hello" })
    local spy_termopen = spy.on(vim.fn, "termopen")

    term:start()

    assert.spy(spy_termopen).was_called_with("echo hello", match.is_table())
  end)

  it("updates the state with the new job_id", function()
    local term = terms.Terminal:new()

    term:start()

    local job_id = term:get_state("job_id")
    assert.is_number(job_id)
  end)

  it("runs the on_create callback", function()
    local called = false
    local term = terms.Terminal:new({
      on_create = function() called = true end,
    })

    term:start()

    assert.is_true(called)
  end)

  it("does nothing if already started", function()
    local term = terms.Terminal:new()
    term:start()
    local initial_bufnr = term:get_state("bufnr")
    local initial_job_id = term:get_state("job_id")

    term:start()

    assert.equal(initial_bufnr, term:get_state("bufnr"))
    assert.equal(initial_job_id, term:get_state("job_id"))
  end)
end)

describe(":is_open", function()
  it("returns false if terminal is not open", function()
    local term = terms.Terminal:new()

    assert.is_false(term:is_open())
  end)

  it("returns true if terminal is open", function()
    local term = terms.Terminal:new()
    term:open()

    assert.is_true(term:is_open())
  end)

  it("returns false if terminal is open in another tab", function()
    local term = terms.Terminal:new()
    term:open("tab")

    assert.is_true(term:is_open())
  end)
end)
