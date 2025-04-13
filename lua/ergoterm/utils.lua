---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")

---@module "ergoterm.config"
local config = lazy.require("ergoterm.config")

local M = {}

---@alias error_types 'error' | 'info' | 'warn'

---@param msg string
---@param level error_types
function M.notify(msg, level)
  local computed_level = level:upper()
  vim.schedule(function() vim.notify(msg, vim.log.levels[computed_level], { title = "Ergoterm" }) end)
end

---@return string?
function M.git_dir()
  local gitdir = vim.fn.system(string.format("git -C %s rev-parse --show-toplevel", vim.fn.expand("%:p:h")))
  local isgitdir = vim.fn.matchstr(gitdir, "^fatal:.*") == ""
  if isgitdir then
    return vim.trim(gitdir)
  else
    M.notify("Not a valid git directory", "error")
  end
end

---@param str string?
---@return boolean
function M.str_is_empty(str)
  return str == nil or str == ""
end

---@param tbl table
---@return table
function M.tbl_filter_empty(tbl)
  return vim.tbl_filter(
    function(str) return not M.str_is_empty(str) end,
    tbl
  )
end

--- TODO: replace with double-indexing on `vim.wo` when neovim/neovim#20288 (hopefully) merges
---@param win number
---@param option string
---@param value any
function M.wo_setlocal(win, option, value)
  vim.api.nvim_set_option_value(option, value, { scope = "local", win = win })
end

---@return boolean
function M.is_windows()
  return vim.fn.has("win32") == 1
end

---@return boolean
function M.is_cmd(shell)
  return shell:find("cmd")
end

---@param shell string
function M.is_pwsh(shell)
  return shell:find("pwsh") or shell:find("powershell")
end

---@param shell string
function M.is_nushell(shell)
  return shell:find("nu")
end

---@return string
function M.get_command_sep()
  return M.is_windows() and M.is_cmd(vim.o.shell) and "&" or ";"
end

---@return string
function M.get_comment_sep()
  return M.is_windows() and M.is_cmd(vim.o.shell) and "::" or "#"
end

---@return string
function M.get_newline_chr()
  local shell = config.get("shell")
  if type(shell) == "function" then shell = shell() end
  if M.is_windows() then
    return M.is_pwsh(shell) and "\r" or "\r\n"
  elseif M.is_nushell(shell) then
    return "\r"
  else
    return "\n"
  end
end

---@param dir string?
---@return string?
function M.get_dir(dir)
  local parsed_dir = nil
  if dir == "git_dir" then
    parsed_dir = M.git_dir()
  elseif dir == nil then
    parsed_dir = vim.loop.cwd()
  else
    parsed_dir = vim.fn.expand(dir)
    if vim.fn.isdirectory(parsed_dir) == 0 then
      M.notify(
        string.format("%s is not a directory", parsed_dir),
        "error"
      )
    end
  end
  return parsed_dir
end

return M
