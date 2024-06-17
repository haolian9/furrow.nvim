local M = {}

---@class furrow.ColSpliter
---@field next fun():string?
---@field rest function():string?

---@param str string
---@param delimiting_pattern string
---@return furrow.ColSpliter
function M.Lua(str, delimiting_pattern)
  local offset = 1

  do --lstrip
    local start, stop = string.find(str, delimiting_pattern, offset, false)
    if start == 1 then offset = stop + 1 end
  end

  return {
    next = function()
      if offset > #str then return end

      local chunk
      local start, stop = string.find(str, delimiting_pattern, offset, false)
      if start and stop then
        local a, b = offset, start - 1
        offset = stop + 1
        chunk = string.sub(str, a, b)
      else
        local a = offset
        offset = #str + 1
        chunk = string.sub(str, a)
      end
      assert(chunk ~= "")
      return chunk
    end,
    rest = function()
      if offset > #str then return end
      local a = offset
      offset = #str + 1
      return string.sub(str, a)
    end,
  }
end

---@param str string
---@param delimiting_pattern string @vim very-magic pattern
---@return furrow.ColSpliter
function M.Vim(str, delimiting_pattern)
  assert(#str > 0)
  local regex = vim.regex([[\v]] .. delimiting_pattern)
  local remain = str

  do --lstrip
    local start, stop = regex:match_str(remain)
    if start == 0 then remain = string.sub(remain, stop + 1) end
  end

  return {
    next = function()
      if #remain == 0 then return end

      local chunk
      ---0-based, (inclusive, exclusive)
      local start, stop = regex:match_str(remain)
      if start and stop then
        start = start + 1 --1-based, inclusive
        stop = stop + 1 --1-based, exclusive
        chunk = string.sub(remain, 1, start - 1)
        remain = string.sub(remain, stop)
      else
        chunk = remain
        assert(chunk ~= "")
        remain = ""
      end
      return chunk
    end,
    rest = function()
      if #remain == 0 then return end
      local chunk = remain
      remain = ""
      return chunk
    end,
  }
end

return M
