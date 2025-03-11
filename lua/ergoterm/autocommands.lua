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
  local _, term = terms.identify()
  if term then
    --- FIXME: we have to reset the filetype here because it is reset by other plugins
    --- i.e. telescope.nvim
    if vim.bo[term.bufnr] ~= constants.FILETYPE then term:__set_ft_options() end
    local closed = ui.close_last_window(term)
    if closed then return end
    if config.persist_mode then
      term:__restore_mode()
    elseif config.start_in_insert then
      term:set_mode(terms.mode.INSERT)
    end
    terms.set_last_focused(term)
  end
  ui.apply_colors()
end

function M.on_win_leave()
  local _, term = terms.identify()
  if not term then return end
  if config.persist_mode then term:persist_mode() end
  if term:is_float() then term:close() end
end

function M.on_term_open()
  local id, term = terms.identify()
  if not term then
    local buf = vim.api.nvim_get_current_buf()
    terms.Terminal
        :new({
          id = id,
          bufnr = buf,
          window = vim.api.nvim_get_current_win(),
          highlights = config.highlights,
          job_id = vim.b[buf].terminal_job_id,
          direction = ui.guess_direction(),
        })
        :__resurrect()
  end
  ui.set_winbar(term)
end

function M.on_colorscheme()
  config.reset_highlights()
  for _, term in pairs(terms.get_all()) do
    if vim.api.nvim_win_is_valid(term.window) then
      vim.api.nvim_win_call(term.window, function() ui.hl_term(term) end)
    end
  end
end

function M.on_filetype(ev)
  local bufnr = ev.buf
  vim.api.nvim_buf_set_option(bufnr, "foldmethod", "manual")
  vim.api.nvim_buf_set_option(bufnr, "foldtext", "foldtext()")
end

-- Setup autocommands for the plugin.
function M.setup()
  vim.api.nvim_create_augroup(constants.AUGROUP, { clear = true })
  local ergoterm_pattern = { "term://*#ergoterm#*", "term://*::ergoterm::*" }

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = ergoterm_pattern,
    group = constants.AUGROUP,
    nested = true, -- this is necessary in case the buffer is the last
    callback = M.on_buf_enter
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    pattern = ergoterm_pattern,
    group = constants.AUGROUP,
    callback = M.on_win_leave
  })

  vim.api.nvim_create_autocmd("TermOpen", {
    pattern = ergoterm_pattern,
    group = constants.AUGROUP,
    callback = M.on_term_open
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = constants.AUGROUP,
    callback = M.on_colorscheme
  })

  -- https://github.com/akinsho/toggleterm.nvim/issues/610
  vim.api.nvim_create_autocmd("FileType", {
    group = constants.AUGROUP,
    pattern = ergoterm_pattern,
    callback = M.on_filetype
  })
end

return M
