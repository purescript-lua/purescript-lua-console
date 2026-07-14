-- Regression guard for the Lua 5.1 FFI of Effect.Console.
--
--   #76 error :: String -> Effect Unit maps to console.error -> stderr in Node;
--       the Lua FFI routed it through print (stdout). Now io.stderr:write.
--   #77 warn -> console.warn -> stderr, likewise (was print/stdout).
--   #268 group/groupCollapsed/groupEnd were missing from the fork. They keep
--        an indentation level: group prints its label and indents subsequent
--        messages by two spaces per open group; groupCollapsed = group (a
--        terminal cannot collapse); groupEnd at level zero is a no-op.
-- log/info/debug correctly stay on stdout (console.log/info/debug all do).
--
-- The FFI reads `print` / `io.stderr` as globals at call time, so we swap them
-- around each call to observe which stream a message lands on.
-- Run from the repo root: `lua test/regression/console.lua`.
local C = dofile("src/Effect/Console.lua")

local failures = 0
local function check(name, cond, detail)
  if cond then
    print("ok   - " .. name)
  else
    failures = failures + 1
    print("FAIL - " .. name .. ": " .. tostring(detail))
  end
end

-- Run `thunk` capturing what it sends to stdout (via print) and stderr.
local function capture(thunk)
  local out, err = {}, {}
  local realPrint, realStderr = print, io.stderr
  print = function(...) out[#out + 1] = table.concat({...}, "\t") end
  io.stderr = {write = function(_, s) err[#err + 1] = s end}
  local ok, e = pcall(thunk)
  print, io.stderr = realPrint, realStderr
  if not ok then error(e) end
  return out, err
end

do
  local out, err = capture(function() C.error("err-msg")() end)
  check("error writes 'err-msg\\n' to stderr", #err == 1 and err[1] == "err-msg\n", "stderr=" .. table.concat(err))
  check("error does not write to stdout", #out == 0, "stdout=" .. table.concat(out, ","))
end

do
  local out, err = capture(function() C.warn("warn-msg")() end)
  check("warn writes 'warn-msg\\n' to stderr", #err == 1 and err[1] == "warn-msg\n", "stderr=" .. table.concat(err))
  check("warn does not write to stdout", #out == 0, "stdout=" .. table.concat(out, ","))
end

do
  local out, err = capture(function() C.log("log-msg")() end)
  check("log writes to stdout", #out == 1 and out[1] == "log-msg", "stdout=" .. table.concat(out, ","))
  check("log does not write to stderr", #err == 0, "stderr=" .. table.concat(err))
end

do
  local out, err = capture(function()
    C.group("outer")()
    C.log("one")()
    C.groupCollapsed("inner")()
    C.warn("two")()
    C.groupEnd()
    C.log("three")()
    C.groupEnd()
    C.log("four")()
  end)
  check("group prints its label at the current indent", out[1] == "outer", "out[1]=" .. tostring(out[1]))
  check("log inside a group is indented by two spaces", out[2] == "  one", "out[2]=" .. tostring(out[2]))
  check("groupCollapsed prints its label like group", out[3] == "  inner", "out[3]=" .. tostring(out[3]))
  check("warn inside nested groups is indented on stderr", err[1] == "    two\n", "err[1]=" .. tostring(err[1]))
  check("groupEnd closes the innermost group", out[4] == "  three", "out[4]=" .. tostring(out[4]))
  check("groupEnd unwinds back to no indent", out[5] == "four", "out[5]=" .. tostring(out[5]))
  check("grouping writes nothing extra", #out == 5 and #err == 1, "#out=" .. #out .. " #err=" .. #err)
end

do
  local out = capture(function()
    C.groupEnd() -- no open group: must be a no-op, not an indent debt
    C.group("g")()
    C.log("m")()
    C.groupEnd()
  end)
  check("groupEnd without an open group is a no-op", out[1] == "g" and out[2] == "  m", "out=" .. table.concat(out, ","))
end

if failures > 0 then error(failures .. " regression check(s) failed") end
print("purescript-lua-console: all FFI regression checks passed")
