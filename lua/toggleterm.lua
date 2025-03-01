local api = vim.api
local fn = vim.fn

local lazy = require("toggleterm.lazy")
---@module "toggleterm.utils"
local utils = lazy.require("toggleterm.utils")
---@module "toggleterm.constants"
local constants = require("toggleterm.constants")
---@module "toggleterm.config"
local config = lazy.require("toggleterm.config")
---@module "toggleterm.ui"
local ui = lazy.require("toggleterm.ui")
---@module "toggleterm.commandline"
local commandline = lazy.require("toggleterm.commandline")

local terms = require("toggleterm.terminal")

local AUGROUP = "ToggleTermCommands"
-----------------------------------------------------------
-- Export
-----------------------------------------------------------
local M = {}

function M.exec(args, term)
  local parsed = commandline.parse(args)
  vim.validate({
    cmd = { parsed.cmd, "string" },
    mode = { parsed.mode, "string", true },
    trim = { parsed.trim, "boolean", true },
    new_line = { parsed.new_line, "boolean", true },
  })
  local callback = function(term)
    term:send({ parsed.cmd }, parsed.mode, parsed.trim, parsed.new_line)
  end
  if term then
    callback(term)
  else
    terms.select_terminal(true, "Please select a terminal to execute command: ", callback)
  end
end

function M.select(args, selection, term)
  local parsed = commandline.parse(args)
  vim.validate({
    mode = { parsed.mode, "string", true },
    trim = { parsed.trim, "boolean", true },
    new_line = { parsed.new_line, "boolean", true },
  })
  local input = ui.select_text(selection)
  local callback = function(term)
    term:send(input, parsed.mode, parsed.trim, parsed.new_line)
  end
  if term then
    callback(term)
  else
    terms.select_terminal(true, "Please select a terminal to send text: ", callback)
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
  term:open(size, direction)
end

function M.update(args, term)
  local parsed = commandline.parse(args)
  vim.validate({
    size = { parsed.size, "number", true },
    dir = { parsed.dir, "string", true },
    direction = { parsed.direction, "string", true },
    name = { parsed.name, "string", true },
  })
  local callback = function(term)
    if parsed.size then term.size = parsed.size end
    if parsed.direction then term.direction = parsed.direction end
    if parsed.name then term.name = parsed.name end
    if term:is_open() then term:refresh() end
  end
  if term then
    callback(term)
  else
    terms.select_terminal(true, "Please select a terminal to update: ", callback)
  end
end

---@param _ ToggleTermConfig
local function setup_autocommands(_)
  api.nvim_create_augroup(AUGROUP, { clear = true })
  local toggleterm_pattern = { "term://*#toggleterm#*", "term://*::toggleterm::*" }

  api.nvim_create_autocmd("BufEnter", {
    pattern = toggleterm_pattern,
    group = AUGROUP,
    nested = true, -- this is necessary in case the buffer is the last
    callback = ui.handle_term_enter,
  })

  api.nvim_create_autocmd("WinLeave", {
    pattern = toggleterm_pattern,
    group = AUGROUP,
    callback = ui.handle_term_leave,
  })

  api.nvim_create_autocmd("TermOpen", {
    pattern = toggleterm_pattern,
    group = AUGROUP,
    callback = ui.on_term_open,
  })

  api.nvim_create_autocmd("ColorScheme", {
    group = AUGROUP,
    callback = function()
      config.reset_highlights()
      for _, term in pairs(terms.get_all()) do
        if api.nvim_win_is_valid(term.window) then
          api.nvim_win_call(term.window, function() ui.hl_term(term) end)
        end
      end
    end,
  })

  api.nvim_create_autocmd("TermOpen", {
    group = AUGROUP,
    pattern = "term://*",
    callback = ui.apply_colors,
  })

  -- https://github.com/akinsho/toggleterm.nvim/issues/610
  api.nvim_create_autocmd("FileType", {
    group = AUGROUP,
    pattern = toggleterm_pattern,
    callback = function(ev)
      local bufnr = ev.buf
      vim.api.nvim_buf_set_option(bufnr, "foldmethod", "manual")
      vim.api.nvim_buf_set_option(bufnr, "foldtext", "foldtext()")
    end,
  })
end

---------------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------------

local function select_terminal(opts)
  terms.select_terminal(true, "Please select a terminal to open (or focus): ", function(term)
    if term:is_open() then
      term:focus()
    else
      term:open()
    end
  end)
end

local function setup_commands()
  local command = api.nvim_create_user_command
  command("TermSelect", select_terminal, { bang = true })
  command(
    "TermExec",
    function(opts)
      if opts.bang then
        M.exec(opts.args, terms.get_last_focused())
      else
        M.exec(opts.args)
      end
    end,
    { complete = commandline.term_exec_complete, nargs = "*", bang = true }
  )

  command(
    "TermNew",
    function(opts) M.new(opts.args) end,
    { complete = commandline.toggle_term_complete, nargs = "*" }
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
        M.select(opts.args, selection, terms.get_last_focused())
      else
        M.select(opts.args, selection)
      end
    end,
    { range = true, nargs = "*", complete = commandline.term_select_complete, bang = true }
  )

  command("TermUpdate", function(opts)
    if opts.bang then
      M.update(opts.args, terms.get_last_focused())
    else
      M.update(opts.args)
    end
  end, { nargs = "?", complete = commandline.term_update_complete, bang = true })
end

function M.setup(user_prefs)
  local conf = config.set(user_prefs)
  setup_autocommands(conf)
  setup_commands()
end

return M
