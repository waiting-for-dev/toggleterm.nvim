local decorators = require("ergoterm.text_decorators")

---@diagnostic disable: undefined-field

describe("text_decorators", function()
  describe(".markdown_code", function()
    local original_bo

    before_each(function()
      original_bo = vim.bo
      vim.bo = { filetype = "lua" }
    end)

    after_each(function()
      vim.bo = original_bo
    end)

    it("wraps text in markdown code block with current filetype", function()
      local input = { "local x = 1", "print(x)" }

      local result = decorators.markdown_code(input)

      assert.same({
        "```lua",
        "local x = 1",
        "print(x)",
        "```",
        ""
      }, result)
    end)

    it("handles empty input", function()
      local input = {}

      local result = decorators.markdown_code(input)

      assert.same({
        "```lua",
        "```",
        ""
      }, result)
    end)

    it("preserves empty lines in the middle but skips trailing empty line", function()
      local input = { "local x = 1", "", "print(x)", "" }

      local result = decorators.markdown_code(input)

      assert.same({
        "```lua",
        "local x = 1",
        "",
        "print(x)",
        "```",
        ""
      }, result)
    end)

    it("uses current buffer filetype", function()
      vim.bo.filetype = "python"
      local input = { "x = 1", "print(x)" }

      local result = decorators.markdown_code(input)

      assert.same({
        "```python",
        "x = 1",
        "print(x)",
        "```",
        ""
      }, result)
    end)

    it("handles empty filetype", function()
      vim.bo.filetype = ""
      local input = { "some text" }

      local result = decorators.markdown_code(input)

      assert.same({
        "```",
        "some text",
        "```",
        ""
      }, result)
    end)
  end)
end)
