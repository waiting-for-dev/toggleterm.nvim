local M = {}

local lazy = require("ergoterm.lazy")
---@module "ergoterm.utils"
local utils = lazy.require("ergoterm.utils")

local fn = vim.fn
local api = vim.api

---@alias SendSelection "single_line" | "visual_selection" | "visual_lines"
--- @class TerminalWindow
--- @field term_id number ID for the terminal in the window
--- @field window number window handle

function M.scroll_to_bottom()
  local info = vim.api.nvim_get_mode()
  if info and (info.mode == "n" or info.mode == "nt") then vim.cmd("normal! G") end
end

--- @param term Terminal
--- @param opening boolean
function M._get_float_config(term, opening)
  local opts = term.float_opts or {}
  local border = opts.border == "curved" or opts.border or "single"

  local width = math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
  local height = math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10)))

  -- width = vim.F.if_nil(M._resolve_size(opts.width, term), width)
  -- height = vim.F.if_nil(M._resolve_size(opts.height, term), height)

  local row = math.ceil(vim.o.lines - height) * 0.5 - 1
  local col = math.ceil(vim.o.columns - width) * 0.5 - 1

  -- row = vim.F.if_nil(M._resolve_size(opts.row, term), row)
  -- col = vim.F.if_nil(M._resolve_size(opts.col, term), col)

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

---Open a floating window
---@param term Terminal
function M.open_float(term)
  local opts = term.float_opts or {}
  local valid_buf = term._state.bufnr and api.nvim_buf_is_valid(term._state.bufnr)
  local buf = valid_buf and term._state.bufnr or api.nvim_create_buf(false, false)
  local win = api.nvim_open_win(buf, true, M._get_float_config(term, true))

  term._state.window, term._state.bufnr = win, buf
  -- partial fix for #391
  utils.wo_setlocal(win, "sidescrolloff", 0)

  if opts.winblend then utils.wo_setlocal(win, "winblend", opts.winblend) end
  term:_set_options()
end

---Updates the floating terminal size
---@param term Terminal
function M.update_float(term)
  if not vim.api.nvim_win_is_valid(term._state.window) then return end
  vim.api.nvim_win_set_config(term._state.window, M._get_float_config(term, false))
end

---Determine if a window is a float
function M.is_float()
  local window = api.nvim_get_current_win()
  return fn.win_gettype(window) == "popup"
end

---Return whether or not the terminal passed in has an open window
---@param term Terminal
---@return boolean
function M.term_has_open_win(term)
  if not term._state.window then return false end
  local wins = {}
  for _, tab in ipairs(api.nvim_list_tabpages()) do
    vim.list_extend(wins, api.nvim_tabpage_list_wins(tab))
  end
  return vim.tbl_contains(wins, term._state.window)
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
      res = M._get_line_selection("visual")
    else
      -- This calls vim.fn.getpos, which uses 1-based indexing for columns
      res = M._get_line_selection("motion")
    end
    start_line, start_col = unpack(res.start_pos)
    -- char, line and block are used for motion/operatorfunc. 'block' is ignored
    if selection_type == "visual_lines" or selection_type == "line" then
      lines = res.selected_lines
    elseif selection_type == "visual_selection" or selection_type == "char" then
      lines = M._get_visual_selection(res, true)
    end
  end
  if not lines or not next(lines) then
    return
  else
    return lines
  end
end

---@private
function M._get_visual_selection(res, motion)
  motion = motion or false
  local mode = fn.visualmode()
  if motion then mode = "v" end

  -- line-visual
  -- return lines encompassed by the selection; already in res object
  if mode == "V" then return res.selected_lines end

  if mode == "v" then
    -- regular-visual
    -- return the buffer text encompassed by the selection
    local start_line, start_col = unpack(res.start_pos)
    local end_line, end_col = unpack(res.end_pos)
    -- exclude the last char in text if "selection" is set to "exclusive"
    if vim.opt.selection:get() == "exclusive" then end_col = end_col - 1 end
    return api.nvim_buf_get_text(0, start_line - 1, start_col - 1, end_line - 1, end_col, {})
  end

  -- block-visual
  -- return the lines encompassed by the selection, each truncated by the start and end columns
  if mode == string.char(22) then
    local _, start_col = unpack(res.start_pos)
    local _, end_col = unpack(res.end_pos)
    -- exclude the last col of the block if "selection" is set to "exclusive"
    if vim.opt.selection:get() == "exclusive" then end_col = end_col - 1 end
    -- exchange start and end columns for proper substring indexing if needed
    -- e.g. instead of str:sub(10, 5), do str:sub(5, 10)
    if start_col > end_col then
      start_col, end_col = end_col, start_col
    end
    -- iterate over lines, truncating each one
    return vim.tbl_map(function(line) return line:sub(start_col, end_col) end, res.selected_lines)
  end
end

---@private
function M._get_line_selection(mode)
  local start_char, end_char = unpack(({
    visual = { "'<", "'>" },
    motion = { "'[", "']" },
  })[mode])
  -- '< marks are only updated when one leaves visual mode.
  -- When calling lua functions directly from a mapping, need to
  -- explicitly exit visual with the escape key to ensure those marks are
  -- accurate.
  vim.cmd("normal! ")

  -- Get the start and the end of the selection
  local start_line, start_col = unpack(fn.getpos(start_char), 2, 3)
  local end_line, end_col = unpack(fn.getpos(end_char), 2, 3)
  local selected_lines = api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  return {
    start_pos = { start_line, start_col },
    end_pos = { end_line, end_col },
    selected_lines = selected_lines,
  }
end

return M
