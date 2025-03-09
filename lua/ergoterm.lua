---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")
---@module "ergoterm.config"
local config = lazy.require("ergoterm.config")
---@module "ergoterm.ui"
local ui = lazy.require("ergoterm.ui")
---@module "ergoterm.commandline"
local commandline = lazy.require("ergoterm.commandline")
---@module "ergoterm.terminal"
local terms = lazy.require("ergoterm.terminal")

local AUGROUP = "ToggleTermCommands"
-----------------------------------------------------------
-- Export
-----------------------------------------------------------
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

---@param _ ToggleTermConfig
local function setup_autocommands(_)
  vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  local ergoterm_pattern = { "term://*#ergoterm#*", "term://*::ergoterm::*" }

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = ergoterm_pattern,
    group = AUGROUP,
    nested = true, -- this is necessary in case the buffer is the last
    callback = ui.handle_term_enter,
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    pattern = ergoterm_pattern,
    group = AUGROUP,
    callback = ui.handle_term_leave,
  })

  vim.api.nvim_create_autocmd("TermOpen", {
    pattern = ergoterm_pattern,
    group = AUGROUP,
    callback = ui.on_term_open,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = AUGROUP,
    callback = function()
      config.reset_highlights()
      for _, term in pairs(terms.get_all()) do
        if vim.api.nvim_win_is_valid(term.window) then
          vim.api.nvim_win_call(term.window, function() ui.hl_term(term) end)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("TermOpen", {
    group = AUGROUP,
    pattern = "term://*",
    callback = ui.apply_colors,
  })

  -- https://github.com/akinsho/toggleterm.nvim/issues/610
  vim.api.nvim_create_autocmd("FileType", {
    group = AUGROUP,
    pattern = ergoterm_pattern,
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

local function select_terminal(picker)
  terms.select_terminal(picker, false, "Please select a terminal to open (or focus): ", picker.select_actions())
end

local function setup_commands(conf)
  local command = vim.api.nvim_create_user_command
  command("TermSelect", function()
    select_terminal(conf.resolved_picker)
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

function M.setup(user_prefs)
  local conf = config.set(user_prefs)
  setup_autocommands(conf)
  setup_commands(conf)
end

return M
