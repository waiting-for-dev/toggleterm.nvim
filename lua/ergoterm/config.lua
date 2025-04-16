---Configuration

---@class PickerCallbackDefinition
---@field fn fun(term: Terminal) the function to run when the user selects a terminal
---@field desc string the description of the action

---@class Picker
---@field select fun(term: Terminal[], prompt: string, callbacks: table<string, PickerCallbackDefinition>)
---@field select_actions fun(): table<string, PickerCallbackDefinition>

local M = {}

local NULL_CALLBACK = function(...) end

---@alias layout "buffer" | "bottom" | "left" | "right" | "tab" | "top" | "float"
---@alias on_close fun(term: Terminal)
---@alias on_create fun(term: Terminal)
---@alias on_focus fun(term: Terminal)
---@alias on_job_exit fun(t: Terminal, job: number, exit_code: number, event: string)
---@alias on_job_stdout fun(t: Terminal, channel_id: number, data: string[], name: string)
---@alias on_job_stnderr fun(t: Terminal, channel_id: number, data: string[], name: string)
---@alias on_open fun(term: Terminal)
---@alias on_stop fun(term: Terminal)
---@alias on_start fun(term: Terminal)

---@class FloatOpts
---@field title_pos? string
---@field width number
---@field height number
---@field relative? string
---@field border? string
---@field zindex? number
---@field title? string
---@field row? number
---@field col? number

---@class ErgoTermConfig
---@field auto_scroll boolean
---@field clear_env boolean
---@field close_on_job_exit boolean
---@field layout layout
---@field float_opts FloatOpts
---@field float_winblend number
---@field on_close on_close
---@field on_create on_create
---@field on_focus on_focus
---@field on_job_exit on_job_exit
---@field on_job_stdout on_job_stdout
---@field on_job_stnderr on_job_stnderr
---@field on_open on_open
---@field on_stop on_stop
---@field on_start on_start
---@field persist_mode boolean
---@field shell string|fun():string
---@field start_in_insert boolean
---@field picker Picker?

---@type ErgoTermConfig
local config = {
  auto_scroll = true,
  clear_env = false,
  close_on_job_exit = true,
  layout = "bottom",
  float_opts = {
    title_pos = "left",
    width = math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20))),
    height = math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10))),
    relative = "editor",
    border = "single",
    zindex = 50
  },
  float_winblend = 10,
  persist_mode = false,
  on_close = NULL_CALLBACK,
  on_create = NULL_CALLBACK,
  on_focus = NULL_CALLBACK,
  on_job_exit = NULL_CALLBACK,
  on_open = NULL_CALLBACK,
  on_stop = NULL_CALLBACK,
  on_start = NULL_CALLBACK,
  on_job_stnderr = NULL_CALLBACK,
  on_job_stdout = NULL_CALLBACK,
  picker = nil,
  shell = vim.o.shell,
  start_in_insert = true,
}

---Get the picker to select terminals
---
---@param conf ErgoTermConfig
---
---@return Picker
function M.build_picker(conf)
  if conf.picker == nil then
    return M._detect_picker()
  else
    return conf.picker
  end
end

function M._detect_picker()
  if require("fzf-lua") then
    return require("ergoterm.pickers.fzf_lua")
  else
    return require("ergoterm.pickers.vim_ui_select")
  end
end

--- get the full user config or just a specified value
---@param key string?
---@return any
function M.get(key)
  if key then return config[key] end
  return config
end

---@param user_conf ErgoTermConfig
---@return ErgoTermConfig
function M.set(user_conf)
  user_conf = user_conf or {}
  config = vim.tbl_deep_extend("force", config, user_conf)
  return config
end

---@return ErgoTermConfig
return setmetatable(M, {
  __index = function(_, k) return config[k] end,
})
