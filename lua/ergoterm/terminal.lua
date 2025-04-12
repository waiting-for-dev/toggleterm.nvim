---Main module giving access to the terminal API

local FILETYPE = "ErgoTerm"

local M = {}

---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")

---@module "ergoterm.autocommands"
local autocommands = lazy.require("ergoterm.autocommands")
---@module "ergoterm.config"
local config = lazy.require("ergoterm.config")
---@module "ergoterm.mode"
local mode = lazy.require("ergoterm.mode")
---@module "ergoterm.ui"
local ui = lazy.require("ergoterm.ui")
---@module "ergoterm.utils"
local utils = lazy.require("ergoterm.utils")

---@class State
---@field last_focused Terminal? Last focused terminal
---@field terminals Terminal[] All terminals
M._state = {
  last_focused = nil,
  terminals = {}
}

---Return currently focused terminal
---
---@return Terminal?
function M.get_focused()
  for _, term in pairs(M._state.terminals) do
    if term:is_focused() then return term end
  end
  return nil
end

---Return the last focused terminal
---
---@return Terminal?
function M.get_last_focused()
  return M._state.last_focused
end

---Return all terminals sorted by id
---
---@return Terminal[]
function M.get_all()
  local result = {}
  for _, v in pairs(M._state.terminals) do
    table.insert(result, v)
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

---Get a single terminal by id
---
---@param id number?
---@return Terminal?
function M.get(id)
  local term = M._state.terminals[id]
  return term
end

---Get a single terminal by name
---
---@param name string
---@return Terminal?
function M.get_by_name(name)
  for _, term in pairs(M._state.terminals) do
    if term.name == name then return term end
  end
  return nil
end

---Get the first terminal that matches a predicate
---
---@param predicate fun(term: Terminal): boolean
---@return Terminal?
function M.find(predicate)
  for _, term in pairs(M._state.terminals) do
    if predicate(term) then return term end
  end
  return nil
end

---Prompts to select an open terminal
---
---@param picker Picker the picker to use
---@param prompt string the prompt to display
---@param callbacks table<string, fun(term: Terminal)> a table of callbacks to run when the user selects a terminal
function M.select(picker, prompt, callbacks)
  local terminals = M.get_all()
  if #terminals == 0 then return utils.notify("No ergoterms are open yet", "info") end
  picker.select(terminals, prompt, callbacks)
end

---@class TerminalState
---@field bufnr number?
---@field cmd string
---@field dir? string
---@field direction direction
---@field float_opts table<string, any>
---@field mode Mode
---@field job_id? number
---@field on_job_exit on_job_exit
---@field on_job_stdout on_job_stdout
---@field on_job_stnderr on_job_stnderr
---@field tabpage number?
---@field window number?

---@class TermCreateArgs
---@field auto_scroll boolean? whether or not to scroll down on terminal output
---@field cmd? string command to run in the terminal
---@field clear_env? boolean use clean job environment, passed to jobstart()
---@field close_on_job_exit boolean? whether or not to close the terminal window when the process exits
---@field dir string? the directory for the terminal
---@field direction direction? the direction to open the terminal in the first time
---@field env? table<string, string> environmental variables passed to jobstart()
---@field name string?
---@field newline_chr? string user specified newline chararacter
---@field float_opts table<string, any>?
---@field float_winblend number
---@field on_close on_close? Callback to run when the terminal is closed. It takes the terminal as an argument.
---@field on_create on_create? Callback to run when the terminal is created. It takes the terminal as an argument.
---@field on_focus on_focus? Callback to run when the terminal is focused. It takes the terminal as an argument.
---@field on_job_exit on_job_exit? Callback to run when the
---@field on_job_stnderr on_job_stnderr?
---@field on_job_stdout on_job_stdout?
---@field on_open on_open?
---@field on_shutdown on_shutdown?
---@field on_start on_start?
---@field persist_mode boolean? whether or not to persist the mode of the terminal on return
---@field start_in_insert boolean?

---@class Terminal : TermCreateArgs
---@field id number
---@field _state TerminalState
local Terminal = {}
Terminal.__index = Terminal

---Create a new terminal object
---
---@param args TermCreateArgs?
---@return Terminal
function Terminal:new(args)
  local conf = config.get()
  local term = args or {} ---@cast term Terminal
  setmetatable(term, self)
  term.auto_scroll = vim.F.if_nil(term.auto_scroll, conf.auto_scroll)
  term.cmd = term.cmd or config.get("shell")
  term.clear_env = vim.F.if_nil(term.clear_env, conf.clear_env)
  term.close_on_job_exit = vim.F.if_nil(term.close_on_job_exit, conf.close_on_job_exit)
  term.direction = term.direction or conf.direction
  term.env = term.env
  term.newline_chr = term.newline_chr or utils.get_newline_chr()
  term.float_opts = vim.tbl_deep_extend("keep", term.float_opts or {}, conf.float_opts)
  term.float_winblend = term.float_winblend or conf.float_winblend
  term.persist_mode = vim.F.if_nil(term.persist_mode, conf.persist_mode)
  term.start_in_insert = vim.F.if_nil(term.start_in_insert, conf.start_in_insert)
  term.on_close = vim.F.if_nil(term.on_close, conf.on_close)
  term.on_create = vim.F.if_nil(term.on_create, conf.on_create)
  term.on_focus = vim.F.if_nil(term.on_focus, conf.on_focus)
  term.on_job_stnderr = vim.F.if_nil(term.on_job_stnderr, conf.on_job_stnderr)
  term.on_job_stdout = vim.F.if_nil(term.on_job_stdout, conf.on_job_stdout)
  term.on_job_exit = vim.F.if_nil(term.on_job_exit, conf.on_job_exit)
  term.on_open = vim.F.if_nil(term.on_open, conf.on_open)
  term.on_shutdown = vim.F.if_nil(term.on_shutdown, conf.on_shutdown)
  term.id = M._build_id()
  term.name = term.name or term.cmd
  term:_initialize_state()
  return term
end

---Update terminal options
---
---@param opts TermCreateArgs
---@return Terminal
function Terminal:update(opts)
  for k, v in pairs(opts) do
    self[k] = v
  end
  self:_recompute_state()
  return self
end

---Returns whether the terminal is started
---
---@return boolean
function Terminal:is_started()
  return self._state.bufnr ~= nil
end

---Start the job in the terminal
---
---It does not open the terminal window
---
---@return self
function Terminal:start()
  if not self:is_started() then
    self._state.bufnr = vim.api.nvim_create_buf(false, false)
    self:_add_to_state()
    vim.api.nvim_buf_call(self._state.bufnr, function()
      self._state.job_id = self:_start_job()
    end)
    autocommands.setup_term_buffer(self)
    self:on_create()
  end
  return self
end

---Check if the terminal is currently open
---
---@return boolean
function Terminal:is_open()
  if not self._state.window then return false end
  local win_type = vim.fn.win_gettype(self._state.window)
  local win_open = win_type == "" or win_type == "popup"
  return win_open and vim.api.nvim_win_get_buf(self._state.window) == self._state.bufnr
end

---Close the terminal window
---
---It's going to run the configured callback
---
---@return Terminal
function Terminal:close()
  if self:is_open() then
    self:on_close()
    vim.api.nvim_win_close(self._state.window, true)
  end
  return self
end

---Open the terminal window without focusing it
---
---@param direction string?
---
---@return self
function Terminal:open(direction)
  if not self:is_started() then self:start() end
  if not self:is_open() then
    local current_win = vim.api.nvim_get_current_win()
    local computed_direction = direction or self._state.direction
    if computed_direction == "top" then
      vim.cmd("split")
    elseif computed_direction == "bottom" then
      vim.cmd("botright split")
    elseif computed_direction == "left" then
      vim.cmd("vsplit")
    elseif computed_direction == "right" then
      vim.cmd("botright vsplit")
    elseif computed_direction == "tab" then
      vim.cmd("tabnew")
      vim.bo.bufhidden = "wipe"
    elseif computed_direction == "float" then
      vim.api.nvim_open_win(self._state.bufnr, true, self._state.float_opts)
    end
    self._state.direction = computed_direction
    self._state.window = vim.api.nvim_get_current_win()
    -- if computed_direction == "float" then
    --   self:_set_float_options()
    -- end
    self._state.tabpage = vim.api.nvim_get_current_tabpage()
    vim.api.nvim_win_set_buf(self._state.window, self._state.bufnr)
    self:_set_options()
    self:on_open()
    vim.api.nvim_set_current_win(current_win)
  end
  return self
end

---Returns whether the terminal is focused
---
---@return boolean
function Terminal:is_focused()
  return self._state.window == vim.api.nvim_get_current_win()
end

---Focus the terminal window
---
---@param direction string?
function Terminal:focus(direction)
  if not self:is_started() then self:start() end
  if not self:is_open() then self:open(direction) end
  if not self:is_focused() then
    vim.api.nvim_set_current_tabpage(self._state.tabpage)
    vim.api.nvim_set_current_win(self._state.window)
    self:_set_last_focused()
    self:_set_initial_mode()
  end
  self:on_focus()
  return self
end

---Shutdown the terminal
---
---Close window and remove buffer
function Terminal:shutdown()
  if self:is_open() then self:close() end
  self:on_shutdown()
  vim.api.nvim_buf_delete(self._state.bufnr, { force = true })
  self:_delete_reference_from_state()
end

---Toggle the terminal window
---
---If the terminal is open, it will be closed. If it's closed, it will be focused
---
---@param direction string?
---
---@return Terminal
function Terminal:toggle(direction)
  if self:is_open() then
    self:close()
  else
    self:focus(direction)
  end
  return self
end

---Send text to the terminal
---
---@param input string[]
---@param action? "interactive"|"visible"|"silent" How to handle the terminal:
---  - "interactive": Opens the terminal and focuses it (user can interact)
---  - "visible": Opens the terminal but keeps focus on original window (user can see output)
---  - "silent": Just sends the command without changing terminal visibility
---@param trim? boolean Whether to trim leading and trailing whitespace from the input
---@param new_line? boolean Whether to add a new line after the input
function Terminal:send(input, action, trim, new_line)
  local computed_action = action or "interactive"
  local computed_trim = trim == nil or trim
  local computed_new_line = new_line == nil or new_line
  local caller_window = vim.api.nvim_get_current_win()
  if computed_new_line then
    table.insert(input, "")
  end
  if computed_trim then
    for i, line in ipairs(input) do
      input[i] = line:gsub("^%s+", ""):gsub("%s+$", "")
    end
  end
  vim.fn.chansend(self._state.job_id, input)
  self:_scroll_bottom()
  if computed_action ~= "silent" and not self:is_open() then
    self:open()
  end
  if computed_action == "interactive" then
    self:focus()
  else
    vim.schedule(function()
      vim.api.nvim_set_current_win(caller_window)
    end)
  end
end

---Clear the terminal screen
function Terminal:clear()
  local clear = utils.is_windows() and "cls" or "clear"
  self:send({ clear })
end

function Terminal:on_buf_enter()
  self:_set_ft_options()
  self:_set_return_mode()
end

function Terminal:on_term_close()
  self:_delete_reference_from_state()
end

function Terminal:on_win_leave()
  if self.persist_mode then self:_persist_mode() end
  if ui.is_float() then self:close() end
end

---@private
function Terminal:_set_ft_options()
  local buf = vim.bo[self._state.bufnr]
  buf.filetype = FILETYPE
  buf.buflisted = false
end

---@private
function Terminal:_set_win_options()
  utils.wo_setlocal(self._state.window, "number", false)
  utils.wo_setlocal(self._state.window, "signcolumn", "no")
  utils.wo_setlocal(self._state.window, "relativenumber", false)
  if self.direction == "float" then
    self:_set_float_options()
  end
end

---@private
function Terminal:_set_options()
  self:_set_ft_options()
  self:_set_win_options()
  vim.b[self._state.bufnr].toggle_number = self.id
end

---@private
function M._build_id()
  local terms = M.get_all()
  for index, term in pairs(terms) do
    if index ~= term.id then return index end
  end
  return #terms + 1
end

---@private
function Terminal:_add_to_state()
  M._state.terminals[self.id] = self
end

---@private
function Terminal:_build_exit_handler(callback)
  return function(job, exit_code, event)
    if self.close_on_job_exit then
      self:close()
      if vim.api.nvim_buf_is_loaded(self._state.bufnr) then
        vim.api.nvim_buf_delete(self._state.bufnr, { force = true })
      end
    end
    callback(self, job, exit_code, event)
  end
end

---@private
function Terminal:_build_output_handler(callback)
  return function(channel_id, data, name)
    if self.auto_scroll then self:_scroll_bottom() end
    callback(self, channel_id, data, name)
  end
end

---@api private
function Terminal:_delete_reference_from_state()
  M._state.terminals[self.id] = nil
end

---@private
function Terminal:_initialize_state()
  self._state = {
    bufnr = nil,
    cmd = self:_build_command(),
    dir = self:_build_dir(),
    direction = self.direction,
    float_opts = self:_build_float_opts(),
    job_id = nil,
    mode = mode.get_initial_mode(self.start_in_insert),
    on_job_exit = self:_build_exit_handler(self.on_job_exit),
    on_job_stdout = self:_build_output_handler(self.on_job_stdout),
    on_job_stnderr = self:_build_output_handler(self.on_job_stnderr),
    tabpage = nil,
    window = nil
  }
end

---@private
function Terminal:_recompute_state()
  self._state.cmd = self:_build_command()
  self._state.mode = mode.get_initial_mode(self.start_in_insert)
  self._state.dir = self:_build_dir()
  self._state.direction = self.direction
  self._state.float_opts = self:_build_float_opts()
  self._state.on_job_exit = self:_build_exit_handler(self.on_job_exit)
  self._state.on_job_stdout = self:_build_output_handler(self.on_job_stdout)
  self._state.on_job_stnderr = self:_build_output_handler(self.on_job_stnderr)
end

---@private
---
---@return string
function Terminal:_build_command()
  local cmd = nil
  if type(self.cmd) == "function" then cmd = self.cmd() else cmd = self.cmd end
  local command_sep = utils.get_command_sep()
  local comment_sep = utils.get_comment_sep()
  cmd = table.concat({
    cmd,
    command_sep,
    comment_sep,
    FILETYPE,
    comment_sep,
    self.id,
  })
  return cmd
end

---@private
function Terminal:_build_dir()
  local dir = nil
  if self.dir == "git_dir" then
    dir = utils.git_dir()
  elseif dir == nil then
    dir = vim.loop.cwd()
  else
    dir = vim.fn.expand(self.dir)
    if vim.fn.isdirectory(dir) == 0 then
      utils.notify(
        string.format("%s is not a directory", dir),
        "error"
      )
    end
  end
  return dir
end

---@private
function Terminal:_build_float_opts()
  local float_opts = self.float_opts
  float_opts.title = self.name
  float_opts.row = math.ceil(vim.o.lines - float_opts.height) * 0.5 - 1
  float_opts.col = math.ceil(vim.o.columns - float_opts.width) * 0.5 - 1
  return float_opts
end

---@private
function Terminal:_start_job()
  return vim.fn.termopen(self.cmd, {
    detach = 1,
    cwd = self.dir,
    on_exit = self._state.on_job_exit,
    on_stdout = self._state.on_job_stdout,
    on_stderr = self._state.on_job_stnderr,
    env = self.env,
    clear_env = self.clear_env,
  })
end

---@private
function Terminal:_restore_mode()
  mode.set(self._state.mode)
  return self
end

---@private
function Terminal:_set_last_focused()
  M._state.last_focused = self
  return self
end

---@private
function Terminal:_set_return_mode()
  if self.persist_mode then
    self:_restore_mode()
  else
    self:_set_initial_mode()
  end
  return self
end

---@private
function Terminal:_persist_mode()
  self._state.mode = mode.get()
  return self
end

---@private
function Terminal:_set_initial_mode()
  mode.set_initial_mode(self.start_in_insert)
  return self
end

---Sets the floating terminal options
function Terminal:_set_float_options()
  utils.wo_setlocal(self._state.window, "sidescrolloff", 0)
  utils.wo_setlocal(self._state.window, "winblend", self.float_winblend)
end

---@private
function Terminal:_scroll_bottom()
  if not vim.api.nvim_buf_is_loaded(self._state.bufnr) or not vim.api.nvim_buf_is_valid(self._state.bufnr) then return end
  if ui.term_has_open_win(self) then vim.api.nvim_buf_call(self._state.bufnr, ui.scroll_to_bottom) end
end

if _G.IS_TEST then
  function M.__reset()
    for _, term in pairs(M._state.terminals) do
      term:shutdown()
    end
  end
end

M.Terminal = Terminal
M.mode = mode

return M
