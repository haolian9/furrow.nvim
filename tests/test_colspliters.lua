local colspliters = require("furrow.colspliters")

local function test_1()
  local s = "    hello   world  yah x y "

  local spliter = colspliters.Vim(s, [[\s+]])

  assert(spliter.next() == "hello")
  assert(spliter.next() == "world")
  assert(spliter.rest() == "yah x y ")
  assert(spliter.rest() == nil)
end

local function test_2()
  local s = "    hello   world  yah x y "

  local spliter = colspliters.Lua(s, [[%s+]])

  -- for chunk in spliter.next do
  --   jelly.debug("'%s'", chunk)
  -- end

  assert(spliter.next() == "hello")
  assert(spliter.next() == "world")
  assert(spliter.rest() == "yah x y ")
  assert(spliter.rest() == nil)
end

local function test_3()
  local s = "    hello   world  yah x y "

  local spliter = colspliters.Vim(s, [[\s+]])

  assert(spliter.next() == "hello")
  assert(spliter.next() == "world")
  assert(spliter.next() == "yah")
  assert(spliter.next() == "x")
  assert(spliter.next() == "y")
  assert(spliter.rest() == nil)
end

test_1()
test_2()
test_3()
