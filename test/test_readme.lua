-- Executes the code snippets documented in README.md, so the docs cannot drift
-- away from the library without a test failing.

package.path = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or ".")
               .. "/?.lua;" .. package.path
local T = require("helper")
local plcLib = T.plcLib

local pins, written = T.mockHAL()

T.section("Pins and Values: dispatch table")
pins["A0"] = 1
T.check('input(plcLib.X0) reads pin "A0"', plcLib.input(plcLib.X0), 1)
T.check("input(1) uses the value 1", plcLib.input(1), 1)

T.section("Pins and Values: memory bit round trip")
local motorRun = {value = 0}
pins["A0"], pins["A1"] = 1, 1
plcLib.input(plcLib.X0)
plcLib.output(motorRun)
T.check("memory bit written from X0", motorRun.value, 1)
plcLib.input(motorRun.value)
plcLib.andBit(plcLib.X1)
plcLib.output(plcLib.Y0)
T.check("read back, AND X1, drive Y0", written["3"], 1)
pins["A1"] = 0
plcLib.input(motorRun.value)
plcLib.andBit(plcLib.X1)
plcLib.output(plcLib.Y0)
T.check("same rung with X1 low", written["3"], 0)

T.section("Pins and Values: the bare-number warning")
T.check("input(3) sets scanValue to 3", plcLib.input(3), 3)
pins["3"] = 1
T.check('input("3") reads the pin', plcLib.input("3"), 1)

T.section("Important Notes: analog normalisation")
pins["A0"] = 512
plcLib.inputAnalog(plcLib.X0)
T.check("inputAnalog leaves 0..1023", plcLib.scanValue, 512)
plcLib.compareGT(500)
T.check("compareGT(500) normalises to 1", plcLib.scanValue, 1)
pins["A1"] = 1
plcLib.andBit(plcLib.X1)
plcLib.output(plcLib.Y0)
T.check("normalised rung drives Y0", written["3"], 1)

T.section("Important Notes: consequence of skipping the comparison")
pins["A0"] = 512
plcLib.inputAnalog(plcLib.X0)
T.check("512 andBit(1) -> 0", plcLib.andBit(1), 0)
plcLib.scanValue = 512
plcLib.output(plcLib.Y0)
T.check("output reads 512 as off", written["3"], 0)

T.section("HAL: tonumber coercion at the boundary")
local numeric = {}
plcLib.setHAL({
    digitalRead  = function(pin) return numeric[tonumber(pin) or pin] or 0 end,
    digitalWrite = function(pin, v) numeric[tonumber(pin) or pin] = v end,
    analogRead   = function() return 0 end,
    analogWrite  = function() end,
    pinMode      = function() end,
    millis       = function() return 0 end,
})
plcLib.scanValue = 1
plcLib.output(plcLib.Y0)
T.check("HAL received numeric pin 3", numeric[3], 1)

T.section("API reference: documented aliases")
T.check("plcLib.i is input", plcLib.i, plcLib.input)
T.check("plcLib.o is output", plcLib.o, plcLib.output)

T.section("Basic Usage: simple digital I/O")
T.mockHAL()
local p, w = T.mockHAL()
p["A0"] = 1
plcLib.input(plcLib.X0)
plcLib.output(plcLib.Y0)
T.check("X0 high drives Y0", w["3"], 1)

T.section("Basic Usage: AND and OR rungs")
p["A0"], p["A1"] = 1, 0
plcLib.input(plcLib.X0)
plcLib.andBit(plcLib.X1)
plcLib.output(plcLib.Y0)
T.check("X0 AND X1 with X1 low", w["3"], 0)
plcLib.input(plcLib.X0)
plcLib.orBit(plcLib.X1)
plcLib.output(plcLib.Y0)
T.check("X0 OR X1 with X1 low", w["3"], 1)

return T.done()
