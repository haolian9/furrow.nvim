local M = {}

---impl notes
---* prefer string[] over str..str, to avoid creating new strings
---  which will be used by string.buffer:put

---@class furrow.Profile
---@field pattern string @delimiting pattern
---@field clods fun(clay:string):string[] @apply to cols[0:-1], before padding
---@field trailing string @apply to cols[0:-1], after padding

do
  local Vim = {}
  Vim.space = {
    pattern = [[\s+]],
    clods = function(clay) return { clay } end,
    trailing = " ",
  }

  Vim["="] = {
    pattern = [[\s*\=\s*]],
    clods = function(clay) return { clay } end,
    trailing = " = ",
  }
  Vim[","] = {
    pattern = [[\s*,\s*]],
    clods = function(clay) return { clay, "," } end,
    trailing = " ",
  }

  M.Vim = Vim
end

return M
