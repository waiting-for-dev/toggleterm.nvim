---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")

---@module "ergoterm.commandline"
local commandline = lazy.require("ergoterm.commandline")
---@module "ergoterm.terminal"
local terms = lazy.require("ergoterm.terminal")
---@module "ergoterm.ui"
local ui = lazy.require("ergoterm.ui")

local M = {}

function M.send(args, selection, picker, term)
  local parsed = commandline.parse(args)
  vim.validate({
    cmd = { parsed.cmd, "string", true },
    mode = { parsed.mode, "string", true },
    trim = { parsed.trim, "boolean", true },
    new_line = { parsed.new_line, "boolean", true },
  })
  local input = nil
  if parsed.cmd then
    input = { parsed.cmd }
  else
    input = ui.select_text(selection)
  end
  local callback = function(t)
    t:send(input, parsed.mode, parsed.trim, parsed.new_line)
  end
  if term then
    callback(term)
  else
    terms.select_terminal(picker, false, "Please select a terminal to send text: ", { default = callback })
  end
end

function M.new(args)
  local parsed = commandline.parse(args)
  vim.validate({
    size = { parsed.size, "number", true },
    dir = { parsed.dir, "string", true },
    direction = { parsed.direction, "string", true },
    name = { parsed.name, "string", true },
  })
  if parsed.size then parsed.size = tonumber(parsed.size) end
  local term = terms.create_term(terms.next_id(), parsed.dir, parsed.direction, parsed.name)
  ui.update_origin_window(term.window)
  term:open(parsed.size, parsed.direction)
end

function M.update(args, picker, term)
  local parsed = commandline.parse(args)
  vim.validate({
    size = { parsed.size, "number", true },
    dir = { parsed.dir, "string", true },
    direction = { parsed.direction, "string", true },
    name = { parsed.name, "string", true },
  })
  local callback = function(t)
    t:update(parsed)
  end
  if term then
    callback(term)
  else
    terms.select_terminal(picker, false, "Please select a terminal to update: ", { default = callback })
  end
end

function M.select(picker)
  terms.select_terminal(picker, false, "Please select a terminal to open (or focus): ", picker.select_actions())
end

function M.setup(conf)
  local command = vim.api.nvim_create_user_command
  command("TermSelect", function()
    M.select(conf.resolved_picker)
  end, { bang = true })

  command(
    "TermNew",
    function(opts) M.new(opts.args) end,
    { complete = commandline.term_new_complete, nargs = "*" }
  )

  command(
    "TermSend",
    function(opts)
      local selection = nil
      if opts.range == 0 then
        selection = "single_line"
      else
        if vim.fn.visualmode() == "V" then
          selection = "visual_lines"
        else
          selection = "visual_selection"
        end
      end
      if opts.bang then
        M.send(opts.args, selection, conf.resolved_picker, terms.get_last_focused())
      else
        M.send(opts.args, selection, conf.resolved_picker)
      end
    end,
    { range = true, nargs = "*", complete = commandline.term_send_complete, bang = true }
  )

  command("TermUpdate", function(opts)
    if opts.bang then
      M.update(opts.args, conf.resolved_picker, terms.get_last_focused())
    else
      M.update(opts.args, conf.resolved_picker)
    end
  end, { nargs = "?", complete = commandline.term_update_complete, bang = true })
end

return M
