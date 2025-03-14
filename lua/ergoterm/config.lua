local constants = require("ergoterm.constants")
local utils = require("ergoterm.utils")

local M = {}

local fmt = string.format

--- @class Responsiveness
--- @field horizontal_breakpoint number

--- @class ErgoTermConfig
--- @field size number
--- @field shade_filetypes string[]
--- @field hide_numbers boolean
--- @field open_mapping string | string[]
--- @field shade_terminals boolean
--- @field insert_mappings boolean
--- @field terminal_mappings boolean
--- @field start_in_insert boolean
--- @field persist_size boolean
--- @field persist_mode boolean
--- @field close_on_exit boolean
--- @field clear_env boolean
--- @field direction  '"horizontal"' | '"vertical"' | '"float"'
--- @field shading_factor number
--- @field shading_ratio number
--- @field shell string|fun():string
--- @field auto_scroll boolean
--- @field float_opts table<string, any>
--- @field autochdir boolean
--- @field title_pos '"left"' | '"center"' | '"right"'
--- @field responsiveness Responsiveness
--- @field resolved_picker Picker

---@type ErgoTermConfig
local config = {
  size = 12,
  shade_filetypes = {},
  hide_numbers = true,
  shade_terminals = true,
  insert_mappings = true,
  terminal_mappings = true,
  start_in_insert = true,
  persist_size = true,
  persist_mode = false,
  close_on_exit = true,
  clear_env = false,
  direction = "horizontal",
  shading_factor = constants.shading_amount,
  shading_ratio = constants.shading_ratio,
  shell = vim.o.shell,
  picker = nil,
  autochdir = false,
  auto_scroll = true,
  float_opts = {
    winblend = 0,
    title_pos = "left",
  },
  responsiveness = {
    horizontal_breakpoint = 0,
  },
}

local function detect_picker()
  if require("fzf-lua") then
    return "fzf-lua"
  else
    return "vim-ui-select"
  end
end

local function get_picker(conf)
  local user_picker = conf.picker or detect_picker()
  if user_picker == "fzf-lua" then
    return require("ergoterm.pickers.fzf-lua")
  else
    return require("ergoterm.pickers.vim-ui-select")
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
  config.resolved_picker = get_picker(config)
  return config
end

---@return ErgoTermConfig
return setmetatable(M, {
  __index = function(_, k) return config[k] end,
})
