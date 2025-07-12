---Text decorators for terminal input

local M = {}

---Wraps text in markdown code block with current buffer's filetype
---@param text string[]
---@return string[]
function M.markdown_code(text)
  local filetype = vim.bo.filetype
  local result = { "```" .. filetype }

  for _, line in ipairs(text) do
    -- Skip empty lines that were added for newlines
    if line ~= "" then
      table.insert(result, line)
    end
  end

  table.insert(result, "```")
  table.insert(result, "") -- Add newline at the end

  return result
end

return M
