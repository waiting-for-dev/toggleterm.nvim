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
  local pickers = require("telescope.pickers")
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  -- Create a custom previewer for terminals
  local terminal_previewer = previewers.new_buffer_previewer({
    title = "Terminal Preview",
    
    get_buffer_by_name = function(_, entry)
      local term = entry.value
      return tostring(term:get_state("bufnr"))
    end,
    
    define_preview = function(self, entry, status)
      local term = entry.value
      local bufnr = term:get_state("bufnr")
      local preview_winid = status.layout.preview and status.layout.preview.winid
      
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        -- Set the terminal buffer directly in the preview window
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(preview_winid) then
            local utils = require("telescope.utils")
            utils.win_set_buf_noautocmd(preview_winid, bufnr)
          end
        end)
      end
    end,
    
    -- Override teardown to prevent terminal buffer deletion
    teardown = function(self)
      -- Don't delete terminal buffers - they should persist
      if self.state then
        self.state.bufnr = nil
        self.state.bufname = nil
      end
    end,
  })

  -- Override the buffer deletion method to protect terminal buffers
  local original_buf_delete = terminal_previewer.state and terminal_previewer.state.buf_delete
  if terminal_previewer.state then
    terminal_previewer.state.buf_delete = function(bufnr)
      -- Check if this is a terminal buffer before allowing deletion
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
        if filetype == terms.FILETYPE then
          -- Don't delete terminal buffers
          return
        end
      end
      -- For non-terminal buffers, use original deletion logic
      if original_buf_delete then
        original_buf_delete(bufnr)
      end
    end
  end

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
