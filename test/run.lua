#!/usr/bin/env lua
-- Runs every plcLib test suite.
--
--     lua test/run.lua
--
-- Individual suites are runnable on their own too:
--
--     lua test/test_bitwise.lua

local here = debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or "."
package.path = here .. "/?.lua;" .. package.path

local T = require("helper")
T.viaRunner = true

local suites = {
    "test_overloads",
    "test_bitwise",
    "test_upstream_quirks",
    "test_readme",
    "test_api",
}

local total, failed = 0, {}

for _, name in ipairs(suites) do
    print("=== " .. name .. " ===")
    T.reset()
    local fails = dofile(here .. "/" .. name .. ".lua")
    total = total + fails
    if fails > 0 then failed[#failed + 1] = name end
end

if total == 0 then
    print(string.format("%d suites, all passing", #suites))
else
    print(string.format("%d failures across: %s", total, table.concat(failed, ", ")))
end

os.exit(total == 0 and 0 or 1)
