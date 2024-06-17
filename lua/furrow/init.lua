local M = {}

local buflines = require("infra.buflines")
local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("", "debug")
local ni = require("infra.ni")
local vsel = require("infra.vsel")

local colspliters = require("furrow.colspliters")
local ropes = require("string.buffer")

local ColSpliter = colspliters.Vim

---@class furrow.Analysis
---@field indents string
---@field max_cols integer
---@field line_cols string[][]
---@field col_width integer[]

---@param lines string[]
---@param delimiting_pattern string
---@param max_cols integer
---@return furrow.Analysis
function M.analyse(lines, delimiting_pattern, max_cols)
  assert(#lines > 1)

  ---@type furrow.Analysis
  local analysis = { indents = "", max_cols = 0, line_cols = {}, col_width = {} }

  analysis.indents = string.match(lines[1], "^%s+") or ""

  for i, _ in ipairs(lines) do
    analysis.line_cols[i] = {}
  end

  local line_iters = {} ---@type {[integer]: {next:fun(), rest:fun()}}
  for i, line in ipairs(lines) do
    line_iters[i] = ColSpliter(line, delimiting_pattern)
  end

  local next_ci = 1

  do
    local remain_line_count = #lines
    local remain_split_count = max_cols --not include .rest() part
    while remain_line_count > 1 and remain_split_count > 1 do
      local keys = dictlib.keys(line_iters) --snapshot
      local has_one = false

      for _, lnum in ipairs(keys) do
        local col_iter = assert(line_iters[lnum])

        local col = col_iter.next()
        if col == nil then
          line_iters[lnum] = nil
          remain_line_count = remain_line_count - 1
        else
          has_one = true
          table.insert(analysis.line_cols[lnum], col)
          analysis.col_width[next_ci] = math.max(analysis.col_width[next_ci] or 0, ni.strwidth(col))
        end
      end

      if has_one then
        next_ci = next_ci + 1
        remain_split_count = remain_split_count - 1
      end
    end
  end

  do --rest
    local keys = dictlib.keys(line_iters)
    local has_one = false
    for _, lnum in ipairs(keys) do
      local col = line_iters[lnum].rest()
      line_iters[lnum] = nil
      if col == nil then
        ---pass
      else
        table.insert(analysis.line_cols[lnum], col)
        analysis.col_width[next_ci] = math.max(analysis.col_width[next_ci] or 0, ni.strwidth(col))
        has_one = true
      end
    end
    if has_one then next_ci = next_ci + 1 end
  end

  ---it's less-than, as there might be not enough cols
  assert(next_ci - 1 <= max_cols, next_ci - 1)
  analysis.max_cols = next_ci - 1

  if next(line_iters) ~= nil then jelly.fatal("RuntimeError", "line_iters should be empty: %s", line_iters) end

  return analysis
end

do
  ---@alias furrow.Gravity 'left'|'center'|'right'

  ---@param str string
  ---@param length integer
  ---@param gravity furrow.Gravity
  ---@return ... string
  local function padding(str, length, gravity)
    local short = length - ni.strwidth(str)
    if short <= 0 then return str end

    if gravity == "center" then
      local left = string.rep(" ", math.floor(short / 2))
      local right = string.rep(" ", math.ceil(short / 2))
      return left, str, right
    end

    local pads = string.rep(" ", short)
    if gravity == "left" then return str, pads end
    if gravity == "right" then return pads, str end

    error("unreachable")
  end

  ---@param analysis furrow.Analysis
  ---@param gravity furrow.Gravity
  ---@return string[]
  function M.furrows(analysis, gravity)
    local lines = {}
    local rope = ropes.new()
    for li, cols in ipairs(analysis.line_cols) do
      if #cols == 0 then goto continue end

      rope:put(analysis.indents)
      for ci = 1, #cols - 1 do
        local col = cols[ci]
        local width = assert(analysis.col_width[ci])
        rope:put(padding(col, width, gravity))
        rope:put(" ")
      end
      ---no trailing spaces
      rope:put(cols[#cols])

      ::continue::
      lines[li] = rope:get()
    end
    return lines
  end
end

return setmetatable(M, {
  ---@param profile? 'space'
  ---@param gravity? furrow.Gravity
  ---@param max_cols? integer @nil=16
  __call = function(_, profile, gravity, max_cols)
    profile = profile or "space"
    max_cols = max_cols or 16
    gravity = gravity or "left"

    local bufnr = ni.get_current_buf()
    local range = vsel.range(bufnr)
    if range == nil then return jelly.warn("no selecting lines") end
    if range.stop_line - range.start_line == 1 then return jelly.info("no need to furrow on one line") end

    local lines = buflines.lines(bufnr, range.start_line, range.stop_line)

    local analysis
    if profile == "space" then
      analysis = M.analyse(lines, [[\s+]], max_cols)
    else
      error("unsupported profile")
    end

    buflines.replaces(bufnr, range.start_line, range.stop_line, M.furrows(analysis, gravity))
  end,
})
