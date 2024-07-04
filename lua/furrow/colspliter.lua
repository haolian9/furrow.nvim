---@class furrow.ColSpliter
---@field next fun():string?
---@field rest function():string?

local empty = {
  next = function() end,
  rest = function() end,
}

---@param str string
---@param delimiting_pattern string @vim very-magic pattern
---@return furrow.ColSpliter
return function(str, delimiting_pattern)
  if #str == 0 then return empty end

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
        chunk = string.sub(remain, 1, start + 1 - 1)
        remain = string.sub(remain, stop + 1)
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
