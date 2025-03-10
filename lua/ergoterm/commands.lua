---ErgoTerm vim commands

---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")

---@module "ergoterm.commandline"
local commandline = lazy.require("ergoterm.commandline")
---@module "ergoterm.terminal"
local terms = lazy.require("ergoterm.terminal")
---@module "ergoterm.ui"
local ui = lazy.require("ergoterm.ui")

local M = {}

---Creates and opens a new terminal
---
---Direction, size, name and working directory can be provided as arguments.
---
---@param args string
function M.new(args)
  local parsed = commandline.parse(args)
  vim.validate({
    size = { parsed.size, "number", true },
    dir = { parsed.dir, "string", true },
    direction = { parsed.direction, "string", true },
    name = { parsed.name, "string", true },
  })
  if parsed.size then parsed.size = tonumber(parsed.size) end
  terms.create_term(parsed.dir, parsed.direction, parsed.size, parsed.name)
end

---Selects a terminal and performs an action
---
---Actions are defined in the picker configuration.
---
---@param conf ErgoTermConfig
function M.select(conf)
  local picker = conf.resolved_picker
  terms.select_terminal(picker, false, "Please select a terminal to open (or focus): ",
    picker.select_actions())
end

---Sends text to a terminal
---
---Text to be sent to the terminal can be provided in different ways:
---
---1. If the `cmd` argument is provided, it will be sent directly to the terminal.
---2. If no `cmd` argument is provided, the text will be extracted from the current buffer depending on the current mode:
---  - `normal`: The current line where the cursor is located.
---  - `visual`: The text selected in visual mode.
---  - `visual_line`: The lines selected in visual mode line-wise.
---
---The `action` argument can be used to specify the behavior after sending the text:
---- `interactive`: The terminal will be opened and focused.
---- `visible`: The terminal will be opened but focus will not change.
---- `silent`: The terminal will not be opened.
---
---The `new_line` argument can be used to add a new line after the text (default is `true`).
---
---The `trim` argument can be used to remove leading and trailing whitespace from the text before sending it.
---
---In bang mode, the last focused terminal will be used. Otherwise, the user will be prompted to select a terminal.
---@param args string
---@param range number
---@param bang boolean
---@param conf ErgoTermConfig
function M.send(args, range, bang, conf)
  local parsed = commandline.parse(args)
  vim.validate({
    cmd = { parsed.cmd, "string", true },
    action = { parsed.action, "string", true },
    trim = { parsed.trim, "boolean", true },
    new_line = { parsed.new_line, "boolean", true },
  })
  local selection = range == 0 and "single_line" or
      (vim.fn.visualmode() == "V" and "visual_lines" or "visual_selection")
  local input = parsed.cmd and { parsed.cmd } or ui.select_text(selection)
  local send_to_terminal = function(t)
    t:send(input, parsed.action, parsed.trim, parsed.new_line)
  end
  if bang then
    send_to_terminal(terms.get_last_focused())
  else
    terms.select_terminal(conf.resolved_picker, false, "Please select a terminal to send text: ",
      { default = send_to_terminal })
  end
end

---Updates a terminal
---
---The following fields can be updated by providing the corresponding arguments: size, dir, direction and name.
---
---In bang mode, the last focused terminal will be used. Otherwise, the user will be prompted to select a terminal.
---
---@param args string
---@param bang boolean
---@param conf ErgoTermConfig
function M.update(args, bang, conf)
  local parsed = commandline.parse(args)
  vim.validate({
    size = { parsed.size, "number", true },
    dir = { parsed.dir, "string", true },
    direction = { parsed.direction, "string", true },
    name = { parsed.name, "string", true },
  })
  local update_terminal = function(t)
    t:update(parsed)
  end
  if bang then
    update_terminal(terms.get_last_focused())
  else
    terms.select_terminal(conf.resolved_picker, false, "Please select a terminal to update: ",
      { default = update_terminal })
  end
end

---Sets up the ErgoTerm default commands
---
---@param conf ErgoTermConfig
function M.setup(conf)
  local command = vim.api.nvim_create_user_command

  command("TermNew", function(opts)
    M.new(opts.args)
  end, { complete = commandline.term_new_complete, nargs = "*" })

  command("TermSelect", function()
    M.select(conf)
  end, { nargs = 0 })

  command("TermSend", function(opts)
    M.send(opts.args, opts.range, opts.bang, conf)
  end, { nargs = "?", complete = commandline.term_send_complete, range = true, bang = true })

  command("TermUpdate", function(opts)
    M.update(opts.args, opts.bang, conf)
  end, { nargs = 1, complete = commandline.term_update_complete, bang = true })
end

return M
