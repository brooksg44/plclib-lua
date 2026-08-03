-- Shared helpers for the plcLib test suites.
--
-- Each suite starts with:
--     package.path = (debug.getinfo(1,"S").source:match("^@(.*)[/\\]") or ".")
--                    .. "/?.lua;" .. package.path
--     local T = require("helper")
-- and ends with:
--     return T.done()

local here = debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or "."
package.path = here .. "/../?.lua;" .. package.path

local T = {}

T.plcLib = require("plcLib")
T.viaRunner = false

local checks, fails = 0, 0

function T.reset()
    checks, fails = 0, 0
end

function T.section(name)
    print("--- " .. name .. " ---")
end

function T.check(label, got, want)
    checks = checks + 1
    if got ~= want then
        fails = fails + 1
        print(string.format("  FAIL %-52s got=%-10s want=%s",
            label, tostring(got), tostring(want)))
        return false
    end
    return true
end

-- Reports a whole block of checks as one line, for loops that would otherwise
-- print hundreds of results.
function T.checkAll(label, mismatches, total)
    checks = checks + 1
    if mismatches ~= 0 then
        fails = fails + 1
        print(string.format("  FAIL %-52s %d/%d mismatched", label, mismatches, total))
        return false
    end
    print(string.format("  ok   %-52s %d/%d", label, total, total))
    return true
end

function T.ok(label)
    print(string.format("  ok   %s", label))
end

-- Installs a mock HAL and returns two tables: pin values that reads see, and
-- the values writes land in. Both are keyed by tostring(pin).
function T.mockHAL()
    local pins, written = {}, {}
    T.plcLib.setHAL({
        digitalRead  = function(pin) return pins[tostring(pin)] or 0 end,
        digitalWrite = function(pin, v) written[tostring(pin)] = v end,
        analogRead   = function(pin) return pins[tostring(pin)] or 0 end,
        analogWrite  = function(pin, v) written[tostring(pin)] = v end,
        pinMode      = function() end,
        millis       = function() return 0 end,
    })
    return pins, written
end

function T.done()
    print(string.format("%d checks, %d failures\n", checks, fails))
    if not T.viaRunner then
        os.exit(fails == 0 and 0 or 1)
    end
    return fails
end

return T
