-- Grouping (group / groupCollapsed / groupEnd) approximates the JS console
-- semantics in a terminal: group prints its label and indents every following
-- message by two more spaces until the matching groupEnd. A terminal cannot
-- collapse a group, so groupCollapsed behaves exactly like group.
local indentLevel = 0

local function indented(s) return string.rep("  ", indentLevel) .. tostring(s) end

local function openGroup(label)
  return function()
    print(indented(label))
    indentLevel = indentLevel + 1
  end
end

return {
  log = (function(s) return function() print(indented(s)) end end),
  warn = (function(s) return function() io.stderr:write(indented(s) .. "\n") end end),
  error = (function(s) return function() io.stderr:write(indented(s) .. "\n") end end),
  info = (function(s) return function() print(indented(s)) end end),
  debug = (function(s) return function() print(indented(s)) end end),
  time = (function(_s) return function() error("Sorry, console timers aren't implemented yet") end end),
  timeLog = (function(_s) return function() error("Sorry, console timers aren't implemented yet") end end),
  timeEnd = (function(_s) return function() error("Sorry, console timers aren't implemented yet") end end),
  clear = (function() io.write("\027[H\027[2J") end),
  group = (openGroup),
  groupCollapsed = (openGroup),
  groupEnd = (function() if indentLevel > 0 then indentLevel = indentLevel - 1 end end)
}
