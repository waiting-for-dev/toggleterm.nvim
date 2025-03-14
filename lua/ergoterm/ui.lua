local M = {}

local lazy = require("ergoterm.lazy")
---@module "ergoterm.constants"
local constants = lazy.require("ergoterm.constants")
---@module "ergoterm.utils"
local utils = lazy.require("ergoterm.utils")
---@module "ergoterm.config"
local config = lazy.require("ergoterm.config")
---@module "ergoterm.terminal"
local terms = lazy.require("ergoterm.terminal")

local fn = vim.fn
local fmt = string.format
local api = vim.api

local origin_window
local persistent = {}

---@alias SendSelection "single_line" | "visual_selection" | "visual_lines"
--- @class TerminalWindow
--- @field term_id number ID for the terminal in the window
--- @field window number window handle
--
--- Save the size of a split window before it is hidden
--- @param direction string
--- @param window number
function M.save_window_size(direction, window)
  if direction == "horizontal" then
    persistent.horizontal = api.nvim_win_get_height(window)
  elseif direction == "vertical" then
    persistent.vertical = api.nvim_win_get_width(window)
  end
end

--- Explicitly set the persistent size of a direction
--- @param direction string
--- @param size number
function M.save_direction_size(direction, size) persistent[direction] = size end

--- @param direction string
--- @return boolean
function M.has_saved_size(direction) return persistent[direction] ~= nil end

--- Get the size of the split. Order of priority is as follows:
--- 1. The size argument is a valid number > 0
--- 2. There is persistent width/height information from prev open state
--- 3. Default/base case config size
---
--- If `config.persist_size = false` then option `2` in the
--- list is skipped.
--- @param size number?
--- @param direction string?
function M.get_size(size, direction)
  local valid_size = size ~= nil and size > 0
  if not config.persist_size then return valid_size and size or config.size end
  return valid_size and size or persistent[direction] or config.size
end

---Create a terminal buffer with the correct buffer/window options
---then set it to current window
---@param term Terminal
local function create_term_buf_if_needed(term)
  local valid_win = term.window and api.nvim_win_is_valid(term.window)
  local window = valid_win and term.window or api.nvim_get_current_win()
  -- If the buffer doesn't exist create a new one
  local valid_buf = term.bufnr and api.nvim_buf_is_valid(term.bufnr)
  local bufnr = valid_buf and term.bufnr or api.nvim_create_buf(false, false)
  -- Assign buf to window to ensure window options are set correctly
  api.nvim_win_set_buf(window, bufnr)
  term.window, term.bufnr = window, bufnr
  term:__set_options()
  api.nvim_set_current_buf(bufnr)
end

function M.create_buf() return api.nvim_create_buf(false, false) end

function M.delete_buf(term)
  if term.bufnr and api.nvim_buf_is_valid(term.bufnr) then
    api.nvim_buf_delete(term.bufnr, { force = true })
  end
end

function M.set_origin_window() origin_window = api.nvim_get_current_win() end

function M.get_origin_window() return origin_window end

function M.update_origin_window(term_window)
  local curr_win = api.nvim_get_current_win()
  if term_window ~= curr_win then origin_window = curr_win end
end

function M.scroll_to_bottom()
  local info = vim.api.nvim_get_mode()
  if info and (info.mode == "n" or info.mode == "nt") then vim.cmd("normal! G") end
end

function M.goto_previous() vim.cmd("wincmd p") end

function M.stopinsert() vim.cmd("stopinsert!") end

---@param buf integer
---@return boolean
local function default_compare(buf)
  return vim.bo[buf].filetype == constants.FILETYPE or vim.b[buf].toggle_number ~= nil
end

--- Find the first open terminal window
--- by iterating all windows and matching the
--- containing buffers filetype with the passed in
--- comparator function or the default which matches
--- the filetype
--- @param comparator function?
--- @return boolean, TerminalWindow[]
function M.find_open_windows(comparator)
  comparator = comparator or default_compare
  local term_wins, is_open = {}, false
  for _, tab in ipairs(api.nvim_list_tabpages()) do
    for _, win in pairs(api.nvim_tabpage_list_wins(tab)) do
      local buf = api.nvim_win_get_buf(win)
      if comparator(buf) then
        is_open = true
        table.insert(term_wins, { window = win, term_id = vim.b[buf].toggle_number })
      end
    end
  end
  return is_open, term_wins
end

---Switch to the given buffer without changing the alternate
---@param buf number
function M.switch_buf(buf)
  -- don't change the alternate buffer so that <c-^><c-^> does nothing in the terminal split
  local cur_buf = api.nvim_get_current_buf()
  if cur_buf ~= buf then vim.cmd(fmt("keepalt buffer %d", buf)) end
end

local split_commands = {
  horizontal = {
    existing = "rightbelow vsplit",
    existing_stacked = "rightbelow split",
    new = "botright split",
    resize = "resize",
  },
  vertical = {
    existing = "rightbelow split",
    new = "botright vsplit",
    resize = "vertical resize",
  },
}

---Guess whether or not the window is a horizontal or vertical split
---this only works if either of the two are full size
---@return string?
function M.guess_direction()
  -- current window is full height vertical split
  -- NOTE: add one for tabline and one for status
  local ui_lines = (vim.o.tabline ~= "" and 1 or 0) + (vim.o.laststatus ~= 0 and 1 or 0)
  if api.nvim_win_get_height(0) + vim.o.cmdheight + ui_lines == vim.o.lines then
    return "vertical"
  end
  -- current window is full width horizontal split
  if api.nvim_win_get_width(0) == vim.o.columns then return "horizontal" end
  return nil
end

--- @private
--- @param size number|function
--- @param term Terminal?
--- @return number?
function M._resolve_size(size, term)
  if not size then
    return
  elseif type(size) == "number" then
    return size
  elseif term and type(size) == "function" then
    return size(term)
  end
  utils.notify(fmt('The input %s is not of type "number" or "function".', size), "error")
end

local curved = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }

--- @private
--- @param term Terminal
--- @param opening boolean
function M._get_float_config(term, opening)
  local opts = term.float_opts or {}
  local border = opts.border == "curved" and curved or opts.border or "single"

  local width = math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
  local height = math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10)))

  width = vim.F.if_nil(M._resolve_size(opts.width, term), width)
  height = vim.F.if_nil(M._resolve_size(opts.height, term), height)

  local row = math.ceil(vim.o.lines - height) * 0.5 - 1
  local col = math.ceil(vim.o.columns - width) * 0.5 - 1

  row = vim.F.if_nil(M._resolve_size(opts.row, term), row)
  col = vim.F.if_nil(M._resolve_size(opts.col, term), col)

  local version = vim.version()

  local float_config = {
    row = row,
    col = col,
    relative = opts.relative or "editor",
    style = opening and "minimal" or nil,
    width = width,
    height = height,
    border = opening and border or nil,
    zindex = opts.zindex or nil,
  }
  if version.major > 0 or version.minor >= 9 then
    float_config.title_pos = term.display_name and opts.title_pos or nil
    float_config.title = term.display_name
  end
  return float_config
end

--- @param size number
--- @param term Terminal
function M.open_split(size, term)
  local has_open, windows = M.find_open_windows()
  local commands = split_commands[term.direction]

  if has_open then
    -- we need to be in the terminal window most recently opened
    -- in order to split it
    local split_win = windows[#windows]
    if config.persist_size then M.save_window_size(term.direction, split_win.window) end
    api.nvim_set_current_win(split_win.window)
    local window_width = vim.o.columns
    local horizontal_breakpoint = config.responsiveness.horizontal_breakpoint
    if term.direction == "horizontal" and window_width < horizontal_breakpoint then
      vim.cmd(commands.existing_stacked)
    else
      vim.cmd(commands.existing)
    end
  else
    vim.cmd(commands.new)
  end

  M.resize_split(term, size)
  create_term_buf_if_needed(term)
end

--- @param term Terminal
function M.open_tab(term)
  -- Open the current buffer in a tab (use tabnew due to issue #95)
  vim.cmd("tabedit new")
  -- tabnew creates an empty no name buffer so we set it to be wiped once it's replaced
  -- by the terminal buffer
  vim.bo.bufhidden = "wipe"
  -- Replace the current window with a tab
  create_term_buf_if_needed(term)
end

---@param term Terminal
local function close_tab(term)
  if #vim.api.nvim_list_tabpages() == 1 then
    return utils.notify("You cannot close the last tab! This will exit neovim", "error")
  end
  api.nvim_win_close(term.window, true)
end

---Close terminal window
---@param term Terminal
local function close_split(term)
  if term.window and api.nvim_win_is_valid(term.window) then
    local persist_size = require("ergoterm.config").get("persist_size")
    if persist_size then M.save_window_size(term.direction, term.window) end
    api.nvim_win_close(term.window, true)
  end
  if origin_window and api.nvim_win_is_valid(origin_window) then
    api.nvim_set_current_win(origin_window)
  else
    origin_window = nil
  end
end

---Open a floating window
---@param term Terminal
function M.open_float(term)
  local opts = term.float_opts or {}
  local valid_buf = term.bufnr and api.nvim_buf_is_valid(term.bufnr)
  local buf = valid_buf and term.bufnr or api.nvim_create_buf(false, false)
  local win = api.nvim_open_win(buf, true, M._get_float_config(term, true))

  term.window, term.bufnr = win, buf
  -- partial fix for #391
  utils.wo_setlocal(win, "sidescrolloff", 0)

  if opts.winblend then utils.wo_setlocal(win, "winblend", opts.winblend) end
  term:__set_options()
end

---Updates the floating terminal size
---@param term Terminal
function M.update_float(term)
  if not vim.api.nvim_win_is_valid(term.window) then return end
  vim.api.nvim_win_set_config(term.window, M._get_float_config(term, false))
end

---Close given terminal's ui
---@param term Terminal
function M.close(term)
  if term:is_split() then
    close_split(term)
  elseif term:is_tab() then
    close_tab(term)
  elseif term.window and api.nvim_win_is_valid(term.window) then
    api.nvim_win_close(term.window, true)
  end
end

---Resize a split window
---@param term Terminal
---@param size number?
function M.resize_split(term, size)
  size = M._resolve_size(M.get_size(size, term.direction), term)
  if config.persist_size and size then M.save_direction_size(term.direction, size) end
  vim.cmd(split_commands[term.direction].resize .. " " .. size)
end

---Determine if a window is a float
---@param window number
function M.is_float(window) return fn.win_gettype(window) == "popup" end

--- @param bufnr number
function M.find_windows_by_bufnr(bufnr) return fn.win_findbuf(bufnr) end

---Return whether or not the terminal passed in has an open window
---@param term Terminal
---@return boolean
function M.term_has_open_win(term)
  if not term.window then return false end
  local wins = {}
  for _, tab in ipairs(api.nvim_list_tabpages()) do
    vim.list_extend(wins, api.nvim_tabpage_list_wins(tab))
  end
  return vim.tbl_contains(wins, term.window)
end

function M.select_text(selection_type)
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
  if not lines or not next(lines) then
    return
  else
    return lines
  end
end

return M
