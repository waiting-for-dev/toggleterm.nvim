local terms = require("toggleterm.terminal")
local constants = require("toggleterm.constants")

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
  local bufnr = term.bufnr
  local name = term.name

  return {                                                                                 
    bufnr = tonumber(bufnr),                                                               
    name = name
  }                                                                                        
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

function M.get_actions(callbacks)
  local actions = {}
  for key, callback in pairs(callbacks) do
    actions[key] = function(selected)
      local id = M.get_term_id_from_selected(selected[1])
      local term = terms.get(id)
      callback(term)
    end
  end
  return actions
end

function M.select_actions()
  return {
    default = terms.Terminal.focus_or_open
  }
end

function M.select(terminals, prompt, callbacks)
  fzf_lua.fzf_exec(
    M.get_options(terminals),
    {
      prompt = prompt,
      actions = M.get_actions(callbacks),
      previewer = M.previewer
    }
  )
end

return M
