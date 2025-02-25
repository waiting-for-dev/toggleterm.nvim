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

--- @param cmd string
--- @param num number?
--- @param size number?
--- @param dir string?
--- @param direction string?
--- @param name string?
--- @param go_back boolean? whether or not to return to original window
--- @param open boolean? whether or not to open terminal window
function M.exec(args, term)
  local parsed = commandline.parse(args)
  vim.validate({
    cmd = { parsed.cmd, "string" },
    focus = { parsed.focus, "boolean", true },
    open = { parsed.open, "boolean", true },
  })
  local callback = function(term)
    term:send(parsed.cmd, parsed.focus, parsed.open)
  end
  if term then
    callback(term)
  else
    terms.select_terminal(true, "Please select a terminal to execute command: ", callback)
  end
end

--- @param selection_type string
--- @param trim_spaces boolean
--- @param cmd_data table<string, any>
function M.send_lines_to_terminal(selection_type, trim_spaces, cmd_data)
  local id = tonumber(cmd_data.args) or 1
  trim_spaces = trim_spaces == nil or trim_spaces

  vim.validate({
    selection_type = { selection_type, "string", true },
    trim_spaces = { trim_spaces, "boolean", true },
    terminal_id = { id, "number", true },
  })

  local current_window = api.nvim_get_current_win() -- save current window

  local lines = {}
  -- Beginning of the selection: line number, column number
  local start_line, start_col
  if selection_type == "single_line" then
    start_line, start_col = unpack(api.nvim_win_get_cursor(0))
    -- nvim_win_get_cursor uses 0-based indexing for columns, while we use 1-based indexing
    start_col = start_col + 1
    table.insert(lines, fn.getline(start_line))
  else
    local res = nil
    if string.match(selection_type, "visual") then
      -- This calls vim.fn.getpos, which uses 1-based indexing for columns
      res = utils.get_line_selection("visual")
    else
      -- This calls vim.fn.getpos, which uses 1-based indexing for columns
      res = utils.get_line_selection("motion")
    end
    start_line, start_col = unpack(res.start_pos)
    -- char, line and block are used for motion/operatorfunc. 'block' is ignored
    if selection_type == "visual_lines" or selection_type == "line" then
      lines = res.selected_lines
    elseif selection_type == "visual_selection" or selection_type == "char" then
      lines = utils.get_visual_selection(res, true)
    end
  end

  if not lines or not next(lines) then return end

  if not trim_spaces then
    M.exec(table.concat(lines, "\n"), id)
  else
    for _, line in ipairs(lines) do
      local l = trim_spaces and line:gsub("^%s+", ""):gsub("%s+$", "") or line
      M.exec(l, id)
    end
  end

  -- Jump back with the cursor where we were at the beginning of the selection
  api.nvim_set_current_win(current_window)
  -- nvim_win_set_cursor() uses 0-based indexing for columns, while we use 1-based indexing
  api.nvim_win_set_cursor(current_window, { start_line, start_col - 1 })
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

---@param selection string
---@param trim_spaces boolean
local function select_terminal_and_send_selection(selection, trim_spaces)
  terms.select_terminal(trim_spaces, "Please select a terminal to send text to: ", function(term)
    M.send_lines_to_terminal(selection, trim_spaces, { args = term.id })
  end)
end

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
      select_terminal_and_send_selection(selection, true)
    end,
    { range = true }
  )

  command(
    "ToggleTermSendVisualLines",
    function(args) M.send_lines_to_terminal("visual_lines", true, args) end,
    { range = true, nargs = "?" }
  )

  command(
    "ToggleTermSendVisualSelection",
    function(args) M.send_lines_to_terminal("visual_selection", true, args) end,
    { range = true, nargs = "?" }
  )

  command(
    "ToggleTermSendCurrentLine",
    function(args) M.send_lines_to_terminal("single_line", true, args) end,
    { nargs = "?" }
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
