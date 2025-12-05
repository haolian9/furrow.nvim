local M = {}

local ropes = require("string.buffer")

local buflines = require("infra.buflines")
local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("furrow", "debug")
local ni = require("infra.ni")
local vsel = require("infra.vsel")

local colspliter = require("furrow.colspliter")
local profiles = require("furrow.profiles")

---@class furrow.Analysis
---@field indents string
---@field line_cols string[][]
---@field col_width integer[]

---@param raw_lines string[]
---@param delimiting_pattern string
---@param max_cols integer
---@return furrow.Analysis
function M.analyse(raw_lines, delimiting_pattern, max_cols)
  assert(#raw_lines > 1)

  ---stripped leading blanks
  local lines = {}
  for i, line in ipairs(raw_lines) do
    lines[i] = assert(select(1, string.gsub(line, "^%s*", "")))
  end

  ---@type furrow.Analysis
  local analysis = { indents = "", line_cols = {}, col_width = {} }

  analysis.indents = string.match(raw_lines[1], "^%s+") or ""

  for i, _ in ipairs(lines) do
    analysis.line_cols[i] = {}
  end

  local line_iters = {} ---@type {[integer]: {next:fun(), rest:fun()}}
  for i, line in ipairs(lines) do
    line_iters[i] = colspliter(line, delimiting_pattern)
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

  if next(line_iters) ~= nil then jelly.fatal("RuntimeError", "line_iters should be empty: %s", line_iters) end

  return analysis
end

do
  ---@alias furrow.Gravity 'left'|'center'|'mid'|'right'

  ---@param rope string.buffer
  ---@param clods string[]
  ---@param clods_length integer
  ---@param pad_length integer
  ---@param pad_gravity furrow.Gravity
  ---@return ... string
  local function padding(rope, clods, clods_length, pad_length, pad_gravity)
    local short = pad_length - clods_length
    if short <= 0 then
      rope:put(unpack(clods))
      return
    end

    if pad_gravity == "center" or pad_gravity == "mid" then
      local left = string.rep(" ", math.floor(short / 2))
      local right = string.rep(" ", math.ceil(short / 2))
      rope:put(left)
      rope:put(unpack(clods))
      rope:put(right)
      return
    end

    local pads = string.rep(" ", short)
    if pad_gravity == "left" then
      rope:put(unpack(clods))
      rope:put(pads)
      return
    end

    if pad_gravity == "right" then
      rope:put(pads)
      rope:put(unpack(clods))
      return
    end

    error("unreachable")
  end

  local rope = ropes.new()

  ---@param analysis furrow.Analysis
  ---@param gravity furrow.Gravity
  ---@param clods fun(clay:string):string[]
  ---@param trailing string
  ---@return string[]
  function M.furrows(analysis, gravity, clods, trailing)
    local lines = {}
    for li, cols in ipairs(analysis.line_cols) do
      if #cols == 0 then goto continue end

      if #cols == 1 then
        rope:put(analysis.indents, cols[1])
        goto continue
      end

      rope:put(analysis.indents)
      for ci = 1, #cols - 1 do --only pad cols[0:-1]
        local col = cols[ci]
        local width = assert(analysis.col_width[ci])
        padding(rope, clods(col), ni.strwidth(col), width, gravity)
        rope:put(trailing)
      end
      ---no trailing spaces
      rope:put(cols[#cols])

      ::continue::
      lines[li] = rope:get()
    end
    return lines
  end
end

---@param mode? ' '|'='|','|':'
---@param gravity? furrow.Gravity
---@param max_cols? integer @nil=16
function M.plough(mode, gravity, max_cols)
  mode = mode or " "
  max_cols = max_cols or 16
  gravity = gravity or "left"

  local bufnr = ni.get_current_buf()
  local range = vsel.range(bufnr, true)
  if range == nil then return jelly.warn("no selecting lines") end
  if range.stop_line - range.start_line < 2 then return jelly.warn("less than 2 lines") end

  local lines = buflines.lines(bufnr, range.start_line, range.stop_line)

  local profile = assert(profiles[mode])
  local analysis = M.analyse(lines, profile.pattern, max_cols)
  local furrows = M.furrows(analysis, gravity, profile.clods, profile.trailing)

  buflines.replaces(bufnr, range.start_line, range.stop_line, furrows)
  vsel.restore_gv(bufnr, range)
end

return M
