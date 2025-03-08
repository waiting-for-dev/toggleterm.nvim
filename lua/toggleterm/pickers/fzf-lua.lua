local terms = require("toggleterm.terminal")
local constants = require("toggleterm.constants")

local M = {}

local fzf_lua = require("fzf-lua")
local builtin = require("fzf-lua.previewer.builtin")

local function get_term_id_from_selected(selected)
  return tonumber(selected:match("(%d+)-"))
end

-- Inherit from the base previewer                                                         
local ToggleTermBufferPreviewer = builtin.base:extend()                                          
function ToggleTermBufferPreviewer:new(o, opts, fzf_win)
  ToggleTermBufferPreviewer.super.new(self, o, opts, fzf_win)
  setmetatable(self, ToggleTermBufferPreviewer)
  return self
end                                                                                        

-- Parse the entry string to extract buffer number                                         
function ToggleTermBufferPreviewer:parse_entry(entry_str)
  local term_id = get_term_id_from_selected(entry_str)
  local term = terms.get(term_id)
  local bufnr = term.bufnr
  local name = term.name

  return {                                                                                 
    bufnr = tonumber(bufnr),                                                               
    name = name
  }                                                                                        
end                                                                                        

-- Populate the preview buffer with terminal buffer contents                               
function ToggleTermBufferPreviewer:populate_preview_buf(entry_str)
  if not self.win or not self.win:validate_preview() then return end                       
  local entry = self:parse_entry(entry_str)                                                
  -- Get the terminal buffer lines                                                         
  local lines = vim.api.nvim_buf_get_lines(entry.bufnr, 0, -1, false)                      
  -- Create a new buffer for preview                                                       
  local tmpbuf = self:get_tmp_buffer()                                                     
  vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, lines)                                  
  vim.bo[tmpbuf].filetype = "sh"
  -- Set the preview buffer                                                                
  self:set_preview_buf(tmpbuf)                                                             

  -- Update title and scrollbar                                                            
  self.win:update_preview_title(" " .. entry.name .. " ")
  self.win:update_preview_scrollbar()                                                      
end                                                                                        

-- Customize window options if needed                                                      
function ToggleTermBufferPreviewer:gen_winopts()
  local winopts = {                                                                        
    wrap = true,                                                                           
    cursorline = false,                                                                    
    number = false                                                                         
  }                                                                                        
  return vim.tbl_extend("keep", winopts, self.winopts)                                     
end                                                                                        

local function get_options(terminals)
  local options = {}
  for _, term in pairs(terminals) do
    table.insert(options, term.id .. "-" .. term.name)
  end
  return options
end

local function get_actions(callbacks)
  local actions = {}
  for key, callback in pairs(callbacks) do
    actions[key] = function(selected)
      local id = get_term_id_from_selected(selected[1])
      local term = terms.get(id)
      callback(term)
    end
  end
  return actions
end

function M.select(terminals, prompt, callbacks)
  fzf_lua.fzf_exec(
    get_options(terminals),
    {
      prompt = prompt,
      actions = get_actions(callbacks),
      previewer = ToggleTermBufferPreviewer
    }
  )
end

return M
