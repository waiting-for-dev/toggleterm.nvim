---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")

---@module "ergoterm.config"
local config = lazy.require("ergoterm.config")
---@module "ergoterm.constants"
local constants = lazy.require("ergoterm.constants")
---@module "ergoterm.ui"
local ui = lazy.require("ergoterm.ui")
---@module "ergoterm.terminal"
local terms = lazy.require("ergoterm.terminal")

local M = {}

function M.on_buf_enter()
  local term = terms.identify()
  term:set_ft_options() -- reset by other plugins like telescope.nvim
  term:set_return_mode()
end

function M.on_win_leave()
  local term = terms.identify()
  if config.persist_mode then term:persist_mode() end
  if ui.is_float() then term:close() end
end

function M.on_filetype(ev)
  local bufnr = ev.buf
  vim.api.nvim_buf_set_option(bufnr, "foldmethod", "manual")
  vim.api.nvim_buf_set_option(bufnr, "foldtext", "foldtext()")
end

function M.on_term_close(term)
  term:_delete_reference_from_state()
end

function M.on_vim_resized_if_float(term)
  ui.update_float(term)
end

-- Setup autocommands for the plugin.
function M.setup()
  vim.api.nvim_create_augroup(constants.AUGROUP, { clear = true })
  local ergoterm_pattern = { "term://*#ergoterm#*", "term://*::ergoterm::*" }

  vim.api.nvim_create_autocmd("BufEnter", {
    group = constants.AUGROUP,
    pattern = ergoterm_pattern,
    nested = true, -- this is necessary in case the buffer is the last
    callback = M.on_buf_enter
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    group = constants.AUGROUP,
    pattern = ergoterm_pattern,
    callback = M.on_win_leave
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = constants.AUGROUP,
    pattern = ergoterm_pattern,
    callback = M.on_filetype
  })
end

function M.setup_term_buffer(term)
  vim.api.nvim_create_augroup(constants.BUFFER_AUGROUP, { clear = true })

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = term.bufnr,
    group = constants.BUFFER_AUGROUP,
    callback = function() M.on_term_close(term) end
  })

  if ui.is_float() then
    vim.api.nvim_create_autocmd("VimResized", {
      buffer = term.bufnr,
      group = constants.BUFFER_AUGROUP,
      callback = function() terms.on_vim_resized_if_float(term) end
    })
  end
end

return M
