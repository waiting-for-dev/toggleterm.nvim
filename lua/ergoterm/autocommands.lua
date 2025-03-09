---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")

---@module "ergoterm.config"
local config = lazy.require("ergoterm.config")
---@module "ergoterm.terminal"
local terms = lazy.require("ergoterm.terminal")
---@module "ergoterm.ui"
local ui = lazy.require("ergoterm.ui")

local AUGROUP = "ToggleTermCommands"

local M = {}

---@param _ ToggleTermConfig
function M.setup(_)
  vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  local ergoterm_pattern = { "term://*#ergoterm#*", "term://*::ergoterm::*" }

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = ergoterm_pattern,
    group = AUGROUP,
    nested = true, -- this is necessary in case the buffer is the last
    callback = ui.handle_term_enter,
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    pattern = ergoterm_pattern,
    group = AUGROUP,
    callback = ui.handle_term_leave,
  })

  vim.api.nvim_create_autocmd("TermOpen", {
    pattern = ergoterm_pattern,
    group = AUGROUP,
    callback = ui.on_term_open,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = AUGROUP,
    callback = function()
      config.reset_highlights()
      for _, term in pairs(terms.get_all()) do
        if vim.api.nvim_win_is_valid(term.window) then
          vim.api.nvim_win_call(term.window, function() ui.hl_term(term) end)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("TermOpen", {
    group = AUGROUP,
    pattern = "term://*",
    callback = ui.apply_colors,
  })

  -- https://github.com/akinsho/toggleterm.nvim/issues/610
  vim.api.nvim_create_autocmd("FileType", {
    group = AUGROUP,
    pattern = ergoterm_pattern,
    callback = function(ev)
      local bufnr = ev.buf
      vim.api.nvim_buf_set_option(bufnr, "foldmethod", "manual")
      vim.api.nvim_buf_set_option(bufnr, "foldtext", "foldtext()")
    end,
  })
end

return M
