local colors = require("ergoterm.colors")
local constants = require("ergoterm.constants")
local utils = require("ergoterm.utils")

local M = {}

local fmt = string.format

local function shade(color, factor) return colors.shade_color(color, factor) end

--- @alias ErgoTermHighlights table<string, table<string, string>>

---@class WinbarOpts
---@field name_formatter fun(term: Terminal):string
---@field enabled boolean

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
--- @field highlights ErgoTermHighlights
--- @field winbar WinbarOpts
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
  winbar = {
    enabled = false,
    name_formatter = function(term) return fmt("%d:%s", term.id, term:_display_name()) end,
  },
  float_opts = {
    winblend = 0,
    title_pos = "left",
  },
  responsiveness = {
    horizontal_breakpoint = 0,
  },
}

---Derive the highlights for a ergoterm and merge these with the user's preferences
---A few caveats must be noted. Since I link the normal and float border to the Normal
---highlight this has to be done carefully as if the user has specified any Float highlights
---themselves merging will result in a mix of user highlights and the link key which is invalid
---so I check that they have not attempted to highlight these themselves. Also
---if they have chosen to shade the terminal then this takes priority over their own highlights
---since they can't have it both ways i.e. custom highlighting and shading
---@param conf ErgoTermConfig
---@return ErgoTermHighlights
local function get_highlights(conf)
  local user = conf.highlights
  local defaults = {
    NormalFloat = vim.F.if_nil(user.NormalFloat, { link = "Normal" }),
    FloatBorder = vim.F.if_nil(user.FloatBorder, { link = "Normal" }),
    StatusLine = { gui = "NONE" },
    StatusLineNC = { cterm = "italic", gui = "NONE" },
  }
  local overrides = {}

  local comment_fg = colors.get_hex("Comment", "fg")
  local dir_fg = colors.get_hex("Directory", "fg")

  local winbar_inactive_opts = { guifg = comment_fg }
  local winbar_active_opts = { guifg = dir_fg, gui = "underline" }

  if conf.shade_terminals then
    local is_bright = colors.is_bright_background()
    local degree = is_bright and conf.shading_ratio or 1
    local amount = conf.shading_factor * degree
    local normal_bg = colors.get_hex("Normal", "bg")
    local terminal_bg = conf.shade_terminals and shade(normal_bg, amount) or normal_bg

    overrides = {
      Normal = { guibg = terminal_bg },
      SignColumn = { guibg = terminal_bg },
      EndOfBuffer = { guibg = terminal_bg },
      StatusLine = { guibg = terminal_bg },
      StatusLineNC = { guibg = terminal_bg },
      winbar_inactive_opts = { guibg = terminal_bg },
      winbar_active_opts = { guibg = terminal_bg },
      WinBarNC = { guibg = terminal_bg },
      WinBar = { guibg = terminal_bg }
    }
  end

  if conf.winbar.enabled then
    colors.set_hl("WinBarActive", winbar_active_opts)
    colors.set_hl("WinBarInactive", winbar_inactive_opts)
  end

  return vim.tbl_deep_extend("force", defaults, conf.highlights, overrides)
end

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

function M.reset_highlights() config.highlights = get_highlights(config) end

---@param user_conf ErgoTermConfig
---@return ErgoTermConfig
function M.set(user_conf)
  user_conf = user_conf or {}
  user_conf.highlights = user_conf.highlights or {}
  config = vim.tbl_deep_extend("force", config, user_conf)
  config.highlights = get_highlights(config)
  config.resolved_picker = get_picker(config)
  return config
end

---@return ErgoTermConfig
return setmetatable(M, {
  __index = function(_, k) return config[k] end,
})
