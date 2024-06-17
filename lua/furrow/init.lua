local buflines = require("infra.buflines")
local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("", "debug")
local ni = require("infra.ni")
local vsel = require("infra.vsel")

local colspliters = require("furrow.colspliters")
local ropes = require("string.buffer")

local ColSpliter = colspliters.Vim

---@class furrow.Analysis
---@field max_cols integer
---@field line_cols string[][]
---@field col_width integer[]

---@param lines string[]
---@param delimiting_pattern string
---@return furrow.Analysis
local function analyse(lines, delimiting_pattern)
  assert(#lines > 1)

  ---@type furrow.Analysis
  local analysis = { max_cols = 0, line_cols = {}, col_width = {} }

  for i, _ in ipairs(lines) do
    analysis.line_cols[i] = {}
  end

  local line_iters = {} ---@type {[integer]: {next:fun(), rest:fun()}}
  for i, line in ipairs(lines) do
    line_iters[i] = ColSpliter(line, delimiting_pattern)
  end

  local next_ci = 1

  local remains = #lines
  while remains > 1 do
    local keys = dictlib.keys(line_iters) --snapshot
    local has_one = false

    for _, lnum in ipairs(keys) do
      local col_iter = line_iters[lnum]
      if col_iter == nil then goto continue end

      local col = col_iter.next()
      if col == nil then
        line_iters[lnum] = nil
        remains = remains - 1
      else
        has_one = true
        table.insert(analysis.line_cols[lnum], col)
        analysis.col_width[next_ci] = math.max(analysis.col_width[next_ci] or 0, ni.strwidth(col))
      end

      ::continue::
    end

    if has_one then next_ci = next_ci + 1 end
  end

  local last_lnum = next(line_iters)
  if last_lnum ~= nil then
    local col = line_iters[last_lnum].rest()
    line_iters[last_lnum] = nil
    if col == nil then --
      ---pass
    else
      table.insert(analysis.line_cols[last_lnum], col)
      analysis.col_width[next_ci] = math.max(analysis.col_width[next_ci] or 0, ni.strwidth(col))
      next_ci = next_ci + 1
    end
  end

  analysis.max_cols = next_ci - 1

  assert(next(line_iters) == nil)

  return analysis
end

local furrows
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
  function furrows(analysis, gravity)
    local lines = {}
    local rope = ropes.new()
    for li, cols in ipairs(analysis.line_cols) do
      for ci = 1, #cols - 1 do
        local col = cols[ci]
        local width = assert(analysis.col_width[ci])
        rope:put(padding(col, width, gravity))
        rope:put(" ")
      end
      ---no trailing spaces
      rope:put(cols[#cols])

      lines[li] = rope:get()
    end
    return lines
  end
end

---@param mode? 'space'
---@param gravity? furrow.Gravity
return function(mode, gravity)
  mode = mode or "space"
  gravity = gravity or "left"

  local bufnr = ni.get_current_buf()
  local range = vsel.range(bufnr)
  if range == nil then return jelly.warn("no selecting lines") end

  local lines = buflines.lines(bufnr, range.start_line, range.stop_line)

  local analysis
  if mode == "space" then
    analysis = analyse(lines, [[\s+]])
  else
    error("unsupported mode")
  end

  buflines.replaces(bufnr, range.start_line, range.stop_line, furrows(analysis, gravity))
end
