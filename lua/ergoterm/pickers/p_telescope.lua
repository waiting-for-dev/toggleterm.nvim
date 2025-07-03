local terms = require("ergoterm.terminal")                                                    
                                                                                              
local M = {}                                                                                  
                                                                                              
function M.select_actions()                                                                   
  return {                                                                                    
    default = { fn = function(term) term:focus() end, desc = "open" },                        
    ["<C-s>"] = { fn = function(term) term:focus("below") end, desc = "open-in-horizontal-split" },                                                                 
    ["<C-v>"] = { fn = function(term) term:focus("right") end, desc = "open-in-vertical-split" },                                                                                            
    ["<C-t>"] = { fn = function(term) term:focus("tab") end, desc = "open-in-tab" },          
    ["<C-f>"] = { fn = function(term) term:focus("float") end, desc = "open-in-float-window" }
  }                                                                                           
end                                                                                           
                                                                                              
function M.select(terminals, prompt, definitions)                                             
  local telescope = require("telescope")                                                      
  local telescope = require("telescope")                                                      
  local telescope = require("telescope")                                                      
  local pickers = require("telescope.pickers")                                                
  local pickers = require("telescope.pickers")                                                
  local pickers = require("telescope.pickers")                                                
  local finders = require("telescope.finders")                                                
  local finders = require("telescope.finders")                                                
  local conf = require("telescope.config").values                                             
  local finders = require("telescope.finders")                                                
  local actions = require("telescope.actions")                                                
  local actions = require("telescope.actions")                                                
  local action_state = require("telescope.actions.state")                                     
  local previewers = require("telescope.previewers")                                          
                                                                                              
  -- Create a custom previewer for terminals                                                  
  local terminal_previewer = previewers.new_buffer_previewer({                                
    title = "Terminal Preview",                                                               
    define_preview = function(self, entry, status)                                            
      local term = entry.value                                                                
      local bufnr = term:get_state("bufnr")                                                   
                                                                                              
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then                                      
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)                         
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)                     
        vim.bo[self.state.bufnr].filetype = "sh"                                              
      else                                                                                    
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"Terminal not started"})  
      end                                                                                     
    end                                                                                       
  })                                                                                          
                                                                                              
  -- Create the picker                                                                        
  pickers.new({}, {                                                                           
    prompt_title = prompt,                                                                    
    finder = finders.new_table({                                                              
      results = terminals,                                                                    
      entry_maker = function(term)                                                            
        return {                                                                              
          value = term,                                                                       
          display = term.id .. "-" .. term.name,                                              
          ordinal = term.id .. "-" .. term.name,                                              
        }                                                                                     
      end,                                                                                    
    }),                                                                                       
    sorter = conf.generic_sorter({}),                                                         
    previewer = terminal_previewer,                                                           
    attach_mappings = function(prompt_bufnr, map)                                             
      -- Map all the actions from definitions                                                 
      for key, definition in pairs(definitions) do                                            
        if key == "default" then                                                              
          actions.select_default:replace(function()                                           
            actions.close(prompt_bufnr)                                                       
            local selection = action_state.get_selected_entry()                               
            definition.fn(selection.value)                                                    
          end)                                                                                
        else                                                                                  
          map("i", key, function()                                                            
            actions.close(prompt_bufnr)                                                       
            local selection = action_state.get_selected_entry()                               
            definition.fn(selection.value)                                                    
          end)                                                                                
          map("n", key, function()                                                            
            actions.close(prompt_bufnr)                                                       
            local selection = action_state.get_selected_entry()                               
            definition.fn(selection.value)                                                    
          end)                                                                                
        end                                                                                   
      end                                                                                     
      return true                                                                             
    end,                                                                                      
  }):find()                                                                                   
end                                                                                           
                                                                                              
return M                                                                                      
 
