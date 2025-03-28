local M = {}

---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")

---@module "ergoterm.autocommands"
local autocommands = lazy.require("ergoterm.autocommands")
---@module "ergoterm.config"
local config = lazy.require("ergoterm.config")
---@module "ergoterm.constants"
local constants = lazy.require("ergoterm.constants")
---@module "ergoterm.mode"
local mode = lazy.require("ergoterm.mode")
---@module "ergoterm.ui"
local ui = lazy.require("ergoterm.ui")
---@module "ergoterm.utils"
local utils = lazy.require("ergoterm.utils")

---@class State
---@field last_focused Terminal?
---@field terminals Terminal[]
local state = {
  ---Last focused terminal in the view.
  last_focused = nil,
  terminals = {}
}

---@class Picker
---@field select fun(term: Terminal[], prompt: string, callbacks: table<string, fun(term: Terminal)>)
---@field select_actions fun(): table<string, fun(term: Terminal)>

---Get the next available id
---
---It's based on the next number in the sequence that
---hasn't already been allocated. E.g. in a list of {1,2,5,6} the next id should
---be 3 then 4 then 7.
---@return integer
function M.next_id()
  local terms = M.get_terminals()
  for index, term in pairs(terms) do
    if index ~= term.id then return index end
  end
  return #terms + 1
end

---Return currently focused terminal
---
---@return Terminal?
function M.get_focused_terminal()
  for _, term in pairs(state.terminals) do
    if term:is_focused() then return term end
  end
  return nil
end

---Return the last focused terminal
---
---@return Terminal?
function M.get_last_focused()
  return state.last_focused
end

---Set the last focused terminal
---
---@param term Terminal
function M.set_last_focused(term)
  state.last_focused = term
end

---Delete a terminal from the list of terminals in the state
---
---@param term Terminal
function M.delete(term)
  if state.terminals[term.id] then state.terminals[term.id] = nil end
end

--- @class TerminalState
--- @field mode Mode

--- @class TermCreateArgs
--- @field auto_scroll boolean? whether or not to scroll down on terminal output
--- @field cmd? string command to run in the terminal
--- @field clear_env? boolean use clean job environment, passed to jobstart()
--- @field close_on_exit boolean? whether or not to close the terminal window when the process exits
--- @field dir string? the directory for the terminal
--- @field env table<string, string> environmental variables passed to jobstart()
--- @field name string?
--- @field newline_chr? string user specified newline chararacter
--- @field float_opts table<string, any>?
--- @field on_close fun(term:Terminal)?
--- @field on_create fun(term:Terminal)?
--- @field on_exit fun(t: Terminal, job: number, exit_code: number?, name: string?)?
--- @field on_open fun(term:Terminal)?
--- @field on_stderr fun(t: Terminal, job: number, data: string[], name: string)?
--- @field on_stdout fun(t: Terminal, job: number, data: string[]?, name: string?)?
--- @field start_in_insert boolean?

--- @class Terminal : TermCreateArgs
--- @field bufnr number
--- @field id number
--- @field job_id number
--- @field window number
--- @field _state TerminalState
local Terminal = {}

---Create a new terminal object
---
---@param args TermCreateArgs?
---@return Terminal
function Terminal:new(args)
  local conf = config.get()
  local term = args or {} ---@cast term Terminal
  self.__index = self
  term.auto_scroll = vim.F.if_nil(term.auto_scroll, conf.auto_scroll)
  term.cmd = term.cmd or config.get("shell")
  term.clear_env = vim.F.if_nil(term.clear_env, conf.clear_env)
  term.close_on_exit = vim.F.if_nil(term.close_on_exit, conf.close_on_exit)
  term.name = term.name or term.cmd or config.get("shell")
  term.env = vim.F.if_nil(term.env, conf.env)
  term.newline_chr = term.newline_chr or utils.get_newline_chr()
  term.float_opts = vim.tbl_deep_extend("keep", term.float_opts or {}, conf.float_opts)
  term.start_in_insert = vim.F.if_nil(term.start_in_insert, conf.start_in_insert)
  term.on_close = vim.F.if_nil(term.on_close, conf.on_close)
  term.on_create = vim.F.if_nil(term.on_create, conf.on_create)
  term.on_exit = vim.F.if_nil(term.on_exit, conf.on_exit)
  term.on_open = vim.F.if_nil(term.on_open, conf.on_open)
  term.on_stderr = vim.F.if_nil(term.on_stderr, conf.on_stderr)
  term.on_stdout = vim.F.if_nil(term.on_stdout, conf.on_stdout)
  term.id = M.next_id()
  term._state = {
    mode = mode.get_initial_mode(term.start_in_insert),
  }
  return setmetatable(term, self)
end

---Update terminal options
---
---@param opts TermCreateArgs
function Terminal:update(opts)
  for k, v in pairs(opts) do
    self[k] = v
  end
end

function Terminal:is_open()
  if not self.window then return false end
  local win_type = vim.fn.win_gettype(self.window)
  -- empty string window type corresponds to a normal window
  local win_open = win_type == "" or win_type == "popup"
  return win_open and vim.api.nvim_win_get_buf(self.window) == self.bufnr
end

function Terminal:set_initial_mode()
  mode.set_initial_mode(self.start_in_insert)
end

function Terminal:set_enter_mode()
  if config.persist_mode then
    self:restore_mode()
  else
    self:set_initial_mode()
  end
end

function Terminal:restore_mode() mode.set(self._state.mode) end

function Terminal:persist_mode() self._state.mode = mode.get() end

function Terminal:close()
  if self.on_close then self:on_close() end
  ui.close(self)
  ui.stopinsert()
  ui.update_origin_window(self.window)
end

function Terminal:shutdown()
  if self:is_open() then self:close() end
  ui.delete_buf(self)
  M.delete(self)
end

function Terminal:scroll_bottom()
  if not vim.api.nvim_buf_is_loaded(self.bufnr) or not vim.api.nvim_buf_is_valid(self.bufnr) then return end
  if ui.term_has_open_win(self) then vim.api.nvim_buf_call(self.bufnr, ui.scroll_to_bottom) end
end

function Terminal:is_focused() return self.window == vim.api.nvim_get_current_win() end

function Terminal:focus()
  if ui.term_has_open_win(self) then vim.api.nvim_set_current_win(self.window) end
end

---Send a command to a running terminal
---@param cmd string|string[] Command(s) to send to the terminal
---@param mode? "interactive"|"visible"|"silent" How to handle the terminal:
---  - "interactive": Opens the terminal and focuses it (user can interact)
---  - "visible": Opens the terminal but keeps focus on original window (user can see output)
---  - "silent": Just sends the command without changing terminal visibility
function Terminal:send(input, mode, trim, new_line)
  local mode = mode or "interactive"
  local trim = trim == nil or trim
  local new_line = new_line == nil or new_line
  local caller_window = vim.api.nvim_get_current_win()
  if new_line then
    table.insert(input, "")
  end
  if trim then
    for i, line in ipairs(input) do
      input[i] = line:gsub("^%s+", ""):gsub("%s+$", "")
    end
  end
  vim.fn.chansend(self.job_id, input)
  self:scroll_bottom()
  if mode ~= "silent" and not self:is_open() then
    self:open()
  end
  if mode == "interactive" then
    self:focus()
  else
    vim.schedule(function()
      vim.api.nvim_set_current_win(caller_window)
    end)
  end
end

--check for os type and perform os specific clear command
function Terminal:clear()
  local clear = utils.is_windows() and "cls" or "clear"
  self:send(clear)
end

---Update the directory of an already opened terminal
---@param dir string
function Terminal:change_dir(dir, mode)
  dir = utils.get_dir(dir)
  if self.dir == dir then return end
  self:send({ string.format("cd %s", dir), self:clear() }, mode)
  self.dir = dir
end

--- Handle when a terminal process exits
---@param term Terminal
local function __handle_exit(term)
  return function(...)
    if term.on_exit then term:on_exit(...) end
    if term.close_on_exit then
      term:close()
      if vim.api.nvim_buf_is_loaded(term.bufnr) then
        vim.api.nvim_buf_delete(term.bufnr, { force = true })
      end
    end
  end
end

---@private
function Terminal:__spawn()
  local cmd = self.cmd
  if type(cmd) == "function" then cmd = cmd() end
  local command_sep = utils.get_command_sep()
  local comment_sep = utils.get_comment_sep()
  cmd = table.concat({
    cmd,
    command_sep,
    comment_sep,
    constants.FILETYPE,
    comment_sep,
    self.id,
  })
  local dir = utils.get_dir(self.dir)
  self.job_id = vim.fn.termopen(cmd, {
    detach = 1,
    cwd = dir,
    on_exit = __handle_exit(self),
    on_stdout = self:_build_output_handler(self.on_stdout),
    on_stderr = self:_build_output_handler(self.on_stderr),
    env = self.env,
    clear_env = self.clear_env,
  })
  self.dir = dir
end

function Terminal:set_ft_options()
  local buf = vim.bo[self.bufnr]
  buf.filetype = constants.FILETYPE
  buf.buflisted = false
end

---@package
function Terminal:__set_win_options()
  if config.hide_numbers then
    utils.wo_setlocal(self.window, "number", false)
    utils.wo_setlocal(self.window, "relativenumber", false)
  end
end

function Terminal:set_options()
  self:set_ft_options()
  self:__set_win_options()
  vim.b[self.bufnr].toggle_number = self.id
end

---Open a terminal in a type of window i.e. a split,full window or tab
---@param term table
---Spawn terminal background job in a buffer without a window
function Terminal:spawn()
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then self.bufnr = ui.create_buf() end
  self:_add_to_state()
  if vim.api.nvim_get_current_buf() ~= self.bufnr then
    vim.api.nvim_buf_call(self.bufnr, function() self:__spawn() end)
  else
    self:__spawn()
  end
  autocommands.setup_term_buffer(self)
  if self.window == vim.api.nvim_get_current_win() then self:set_initial_mode() end
  if self.on_create then self:on_create() end
end

---Open a terminal window
---@param direction string?
function Terminal:open(direction)
  local cwd = vim.fn.getcwd()
  self.dir = utils.get_dir(config.autochdir and cwd or self.dir)
  ui.set_origin_window()
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    local ok, err = ui.open(direction, self)
    if not ok and err then return utils.notify(err, "error") end
    self:spawn()
  else
    local ok, err = ui.open(direction, self)
    if not ok and err then return utils.notify(err, "error") end
    -- ui.switch_buf(self.bufnr)
    if config.autochdir and self.dir ~= cwd then self:change_dir(cwd) end
  end
  -- NOTE: it is important that this function is called at this point. i.e. the buffer has been correctly assigned
  if self.on_open then self:on_open() end
  M.set_last_focused(self)
  return self
end

function Terminal:focus_or_open(direction)
  if self:is_open() then
    self:focus()
  else
    self:open(direction)
  end
end

function Terminal:toggle(direction)
  if self:is_open() then
    self:close()
  else
    self:open(direction)
  end
  return self
end

--- get the toggle term number from
--- the name e.g. term://~/.dotfiles//3371887:/usr/bin/zsh;#ergoterm#1
--- the number in this case is 1
--- @param name string?
--- @return Terminal
function M.identify(name)
  name = name or vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local comment_sep = utils.get_comment_sep()
  local parts = vim.split(name, comment_sep)
  local id = tonumber(parts[#parts])
  return state.terminals[id]
end

---get existing terminal or create an empty term table
---@param num number?
---@param dir string?
---@param name string?
---@return Terminal
---@return boolean
function M.get_or_create_term(dir, name)
  local term = M.get(num)
  if term then return term, false end
  return Terminal:new({ dir = dir, name = name })
end

function M.create_term(dir, direction, name)
  local term = Terminal:new({ dir = dir, direction = direction, name = name })
  ui.update_origin_window(term.window)
  term:open(direction)
  return term
end

---Get a single terminal by id
---@param id number?
---@return Terminal?
function M.get(id)
  local term = state.terminals[id]
  return term
end

---Get the first terminal that matches a predicate
---@param predicate fun(term: Terminal): boolean
---@return Terminal?
function M.find(predicate)
  if type(predicate) ~= "function" then
    utils.notify("terminal.find expects a function, got " .. type(predicate), "error")
    return
  end
  for _, term in pairs(state.terminals) do
    if predicate(term) then return term end
  end
  return nil
end

---Return the potentially non contiguous map of terminals as a sorted array
---@return Terminal[]
function M.get_terminals()
  local result = {}
  for _, v in pairs(state.terminals) do
    table.insert(result, v)
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

-- Prompts to select an open terminal
--
-- @param prompt string the prompt to display
-- @param callback fun the function to call with the selected terminal
function M.select_terminal(picker, prompt, callbacks)
  local terminals = state.terminals or M.get_terminals()
  if #terminals == 0 then return utils.notify("No ergoterms are open yet", "info") end
  picker.select(terminals, prompt, callbacks)
end

---@private
function Terminal:_add_to_state()
  state.terminals[self.id] = self
end

---@private
function Terminal:_build_output_handler(callback)
  return function(...)
    if self.auto_scroll then self:scroll_bottom() end
    if callback then callback(self, ...) end
  end
end

if _G.IS_TEST then
  function M.__reset()
    for _, term in pairs(state.terminals) do
      term:shutdown()
    end
  end

  M.__next_id = M.next_id
end

M.Terminal = Terminal
M.mode = mode

return M
