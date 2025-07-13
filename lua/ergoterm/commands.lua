---ErgoTerm vim commands

---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")

---@module "ergoterm.commandline"
local commandline = lazy.require("ergoterm.commandline")
---@module "ergoterm.config"
local config = lazy.require("ergoterm.config")
---@module "ergoterm.terminal"
local terms = lazy.require("ergoterm.terminal")
---@module "ergoterm.text_decorators"
local text_decorators = lazy.require("ergoterm.text_decorators")
---@module "ergoterm.text_selector"
local text_selector = lazy.require("ergoterm.text_selector")
---@module "ergoterm.utils"
local utils = lazy.require("ergoterm.utils")

local M = {}

---Creates and opens a new terminal
---
---layout, name and working directory can be provided as arguments.
---
---@param args string
function M.new(args)
  local parsed = commandline.parse(args)
  vim.validate({
    dir = { parsed.dir, "string", true },
    layout = { parsed.layout, "string", true },
    name = { parsed.name, "string", true },
  })
  terms.Terminal:new({ dir = parsed.dir, layout = parsed.layout, name = parsed.name }):focus()
end

---Selects a terminal and performs an action
---
---Actions are defined in the picker configuration.
---
---@param picker Picker
function M.select(picker)
  terms.select(picker, "Please select a terminal to open (or focus): ",
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
---The `decorator` argument can be used to specify a text decorator function that will be applied to the text before sending it. It can be one of the following:
--- - `identity`: No changes to the text.
--- - `markdown_code`: Wraps the text in a markdown code block with the current buffer's filetype.
---
---In bang mode, the last focused terminal will be used. Otherwise, the user will be prompted to select a terminal.
---@param args string
---@param range number
---@param bang boolean
---@param picker Picker
function M.send(args, range, bang, picker)
  local parsed = commandline.parse(args)
  vim.validate({
    cmd = { parsed.cmd, "string", true },
    action = { parsed.action, "string", true },
    decorator = { parsed.decorator, "string", true },
    trim = { parsed.trim, "boolean", true },
    new_line = { parsed.new_line, "boolean", true },
  })
  local selection = range == 0 and "single_line" or
      (vim.fn.visualmode() == "V" and "visual_lines" or "visual_selection")
  local input = parsed.cmd and { parsed.cmd } or text_selector.select(selection)

  local decorator_name = parsed.decorator or text_decorators.DECORATORS.IDENTITY
  local decorator = text_decorators[decorator_name]

  local send_to_terminal = function(t)
    t:send(input, parsed.action, parsed.trim, parsed.new_line, decorator)
  end
  if bang then
    local term = terms.get_last_focused()
    if not term then
      return utils.notify("No terminals are open", "error")
    else
      send_to_terminal(term)
    end
  else
    terms.select(picker, "Please select a terminal to send text: ",
      { default = { fn = send_to_terminal, desc = "send-text" } })
  end
end

---Updates a terminal
---
---The following fields can be updated by providing the corresponding arguments: dir, layout and name.
---
---In bang mode, the last focused terminal will be used. Otherwise, the user will be prompted to select a terminal.
---
---@param args string
---@param bang boolean
---@param picker Picker
function M.update(args, bang, picker)
  local parsed = commandline.parse(args)
  vim.validate({
    dir = { parsed.dir, "string", true },
    layout = { parsed.layout, "string", true },
    name = { parsed.name, "string", true },
  })
  local update_terminal = function(t)
    t:update(parsed)
  end
  if bang then
    local term = terms.get_last_focused()
    if not term then
      return utils.notify("No terminals are open", "error")
    else
      update_terminal(terms.get_last_focused())
    end
  else
    terms.select(picker, "Please select a terminal to update: ",
      { default = { fn = update_terminal, desc = "update-terminal" } })
  end
end

---Sets up the ErgoTerm default commands
---
---@param conf ErgoTermConfig
function M.setup(conf)
  local command = vim.api.nvim_create_user_command
  local picker = config.build_picker(conf)

  command("TermNew", function(opts)
    M.new(opts.args)
  end, { complete = commandline.term_new_complete, nargs = "*" })

  command("TermSelect", function()
    M.select(picker)
  end, { nargs = 0 })

  command("TermSend", function(opts)
    M.send(opts.args, opts.range, opts.bang, picker)
  end, { nargs = "?", complete = commandline.term_send_complete, range = true, bang = true })

  command("TermUpdate", function(opts)
    M.update(opts.args, opts.bang, picker)
  end, { nargs = 1, complete = commandline.term_update_complete, bang = true })
end

return M
