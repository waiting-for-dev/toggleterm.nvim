local M = {}

function M.select(terminals, prompt, callbacks)
  vim.ui.select(terminals, {
    prompt = "Select a terminal",
    format_item = function(term) return term.id .. ": " .. term.name end,
  }, function(term)
      callbacks.default(term)
    end)
end

return M
