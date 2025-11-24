local M = {}

---impl notes
---* prefer string[] over str..str, to avoid creating new strings
---  which will be used by string.buffer:put

---@class furrow.Profile
---@field pattern string @delimiting pattern
---@field clods fun(clay:string):string[] @apply to cols[0:-1], before padding
---@field trailing string @apply to cols[0:-1], after padding

M[" "] = {
  pattern = [[\s+]],
  clods = function(clay) return { clay } end,
  trailing = " ",
}

M["="] = {
  pattern = [[\s*\=\s*]],
  clods = function(clay) return { clay } end,
  trailing = " = ",
}

M[","] = {
  pattern = [[\s*,\s*]],
  clods = function(clay) return { clay, "," } end,
  trailing = " ",
}

M[":"] = {
  pattern = [[\s*:\s*]],
  clods = function(clay) return { clay, ":" } end,
  trailing = " ",
}

M["#"] = {
  pattern = [[\s*#\s*]],
  clods = function(clay) return { clay } end,
  trailing = " # ",
}

return M
