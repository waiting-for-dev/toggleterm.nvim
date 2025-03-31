local M = {}

local lazy = require("ergoterm.lazy")
---@module "ergoterm.constants"
local constants = lazy.require("ergoterm.constants")
---@module "ergoterm.utils"
local utils = lazy.require("ergoterm.utils")

local fn = vim.fn
local fmt = string.format
local api = vim.api

---@alias SendSelection "single_line" | "visual_selection" | "visual_lines"
--- @class TerminalWindow
--- @field term_id number ID for the terminal in the window
--- @field window number window handle

---Create a terminal buffer with the correct buffer/window options
---then set it to current window
---@param term Terminal
function M.create_term_buf_if_needed(term)
  local valid_win = term.window and api.nvim_win_is_valid(term.window)
  local window = valid_win and term.window or api.nvim_get_current_win()
  -- If the buffer doesn't exist create a new one
  local valid_buf = term.bufnr and api.nvim_buf_is_valid(term.bufnr)
  local bufnr = valid_buf and term.bufnr or api.nvim_create_buf(false, false)
  -- Assign buf to window to ensure window options are set correctly
  api.nvim_win_set_buf(window, bufnr)
  term.window, term.bufnr = window, bufnr
  term:set_options()
  api.nvim_set_current_buf(bufnr)
end

function M.create_buf() return api.nvim_create_buf(false, false) end

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

--- @param term Terminal
--- @param opening boolean
function M._get_float_config(term, opening)
  local opts = term.float_opts or {}
  local border = opts.border == "curved" or opts.border or "single"

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
    float_config.title_pos = term.name and opts.title_pos or nil
    float_config.title = term.name
  end
  return float_config
end

---@param term Terminal
function M.open(direction, term)
  local direction = direction or "bottom"
  if direction == "top" then
    vim.cmd("split")
    M.create_term_buf_if_needed(term)
  elseif direction == "bottom" then
    vim.cmd("botright split")
    M.create_term_buf_if_needed(term)
  elseif direction == "left" then
    vim.cmd("vsplit")
    M.create_term_buf_if_needed(term)
  elseif direction == "right" then
    vim.cmd("botright vsplit")
    M.create_term_buf_if_needed(term)
  elseif direction == "tab" then
    vim.cmd("tabnew")
    vim.bo.bufhidden = "wipe"
    M.create_term_buf_if_needed(term)
  elseif direction == "buffer" then
    M.create_term_buf_if_needed(term)
  elseif direction == "float" then
    M.open_float(term)
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
  term:set_options()
end

---Updates the floating terminal size
---@param term Terminal
function M.update_float(term)
  if not vim.api.nvim_win_is_valid(term.window) then return end
  vim.api.nvim_win_set_config(term.window, M._get_float_config(term, false))
end

---Determine if a window is a float
function M.is_float()
  local window = api.nvim_get_current_win()
  return fn.win_gettype(window) == "popup"
end

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
