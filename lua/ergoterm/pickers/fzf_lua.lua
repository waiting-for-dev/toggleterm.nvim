local terms = require("ergoterm.terminal")

local M = {}

local fzf_lua = require("fzf-lua")
local fzf_lua_builtin_previewer = require("fzf-lua.previewer.builtin")

function M.get_term_id_from_selected(selected)
  return tonumber(selected:match("(%d+)-"))
end

M.previewer = fzf_lua_builtin_previewer.base:extend()

function M.previewer:new(o, opts, fzf_win)
  M.previewer.super.new(self, o, opts, fzf_win)
  setmetatable(self, M.previewer)
  return self
end

function M.previewer:parse_entry(entry_str)
  local term_id = M.get_term_id_from_selected(entry_str)
  local term = terms.get(term_id)
  if term then
    local bufnr = term:get_state("bufnr")
    local name = term.name

    return {
      bufnr = tonumber(bufnr),
      name = name
    }
  end
end

function M.previewer:populate_preview_buf(entry_str)
  if not self.win or not self.win:validate_preview() then return end
  local entry = self:parse_entry(entry_str)
  local lines = vim.api.nvim_buf_get_lines(entry.bufnr, 0, -1, false)
  local tmpbuf = self:get_tmp_buffer()
  vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, lines)
  vim.bo[tmpbuf].filetype = "sh"
  self:set_preview_buf(tmpbuf)
  self.win:update_preview_title(" " .. entry.name .. " ")
  self.win:update_preview_scrollbar()
end

function M.previewer:gen_winopts()
  local winopts = {
    wrap = true,
    cursorline = false,
    number = false
  }
  return vim.tbl_extend("keep", winopts, self.winopts)
end

function M.get_options(terminals)
  local options = {}
  for _, term in pairs(terminals) do
    table.insert(options, term.id .. "-" .. term.name)
  end
  return options
end

function M.get_actions(definitions)
  local actions = {}
  for key, definition in pairs(definitions) do
    actions[key] = {
      desc = definition.desc,
      fn = function(selected)
        local id = M.get_term_id_from_selected(selected[1])
        local term = terms.get(id)
        definition.fn(term)
      end
    }
  end
  return actions
end

function M.select_actions()
  return {
    default = { fn = function(term) term:focus() end, desc = "open" },
    ["ctrl-s"] = { fn = function(term) term:focus("bottom") end, desc = "open-in-horizontal-split" },
    ["ctrl-v"] = { fn = function(term) term:focus("right") end, desc = "open-in-vertical-split" },
    ["ctrl-t"] = { fn = function(term) term:focus("tab") end, desc = "open-in-tab" },
    ["ctrl-f"] = { fn = function(term) term:focus("float") end, desc = "open-in-float-window" }
  }
end

function M.select(terminals, prompt, definitions)
  fzf_lua.fzf_exec(
    M.get_options(terminals),
    {
      prompt = prompt,
      actions = M.get_actions(definitions),
      previewer = M.previewer
    }
  )
end

return M
