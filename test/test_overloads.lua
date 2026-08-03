-- Pin/value dispatch.
--
-- The Arduino original selects between reading a pin and using a value with
-- C++ overloads: in(int) calls digitalRead(), in(unsigned int) uses the
-- argument directly. Lua has one number type, so the pin case is carried by
-- strings. Every pin constant must therefore be a string, or calls like
-- input(plcLib.Y0) silently load a literal instead of reading hardware.

package.path = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or ".")
               .. "/?.lua;" .. package.path
local T = require("helper")
local plcLib = T.plcLib

local pins, written = T.mockHAL()

T.section("every pin constant is a string")
local bad = 0
local names = {"X0","X1","X2","X3","X4","X5","X6","X7",
               "Y0","Y1","Y2","Y3","Y4","Y5","Y6","Y7",
               "DIRA","DIRB","PWMA","PWMB","BRAKEA","BRAKEB","CURRENTA","CURRENTB"}
for _, name in ipairs(names) do
    if type(plcLib[name]) ~= "string" then
        bad = bad + 1
        print("       " .. name .. " is a " .. type(plcLib[name]))
    end
end
T.checkAll("pin constants typed as strings", bad, #names)

T.section("in(int) overload reaches the hardware")
pins["3"] = 1
T.check("input(Y0) with pin 3 high", plcLib.input(plcLib.Y0), 1)
pins["3"] = 0
T.check("input(Y0) with pin 3 low", plcLib.input(plcLib.Y0), 0)
T.check("input(Y0) is not the literal 3", plcLib.scanValue ~= 3, true)

T.section("in(unsigned int) overload uses the value")
T.check("input(1)", plcLib.input(1), 1)
T.check("input(0)", plcLib.input(0), 0)
local memBit = 1
T.check("input(memBit) reads back a memory bit", plcLib.input(memBit), 1)

T.section("both overloads across every dispatching function")
pins["A0"] = 1
local cases = {
    {"input",       plcLib.input,       1, 1},
    {"inputNot",    plcLib.inputNot,    0, 0},
    {"inputAnalog", plcLib.inputAnalog, 1, 1},
    {"andBit",      plcLib.andBit,      1, 1},
    {"andNotBit",   plcLib.andNotBit,   0, 0},
    {"orBit",       plcLib.orBit,       1, 1},
    {"orNotBit",    plcLib.orNotBit,    1, 1},
    {"xorBit",      plcLib.xorBit,      0, 0},
}
for _, c in ipairs(cases) do
    local name, fn, wantPin, wantValue = c[1], c[2], c[3], c[4]
    plcLib.scanValue = 1
    T.check(name .. "(X0) pin overload, A0 high", fn(plcLib.X0), wantPin)
    plcLib.scanValue = 1
    T.check(name .. "(1) value overload", fn(1), wantValue)
end

T.section("output pin identifiers reach the HAL verbatim")
plcLib.scanValue = 1
plcLib.output(plcLib.Y0)
T.check("output(Y0) writes HAL pin '3'", written["3"], 1)
plcLib.scanValue = 0
plcLib.output(plcLib.Y1)
T.check("output(Y1) writes HAL pin '5'", written["5"], 0)
plcLib.scanValue = 1
plcLib.outputNot(plcLib.Y2)
T.check("outputNot(Y2) writes HAL pin '6'", written["6"], 0)
plcLib.scanValue = 1023
plcLib.outputPWM(plcLib.PWMA)
T.check("outputPWM(PWMA) writes 1023/4", written["3"], 255)

T.section("table references still write to the variable")
local memory = {value = 0}
plcLib.scanValue = 1
plcLib.output(memory)
T.check("output(table) sets .value", memory.value, 1)
plcLib.scanValue = 1
plcLib.outputNot(memory)
T.check("outputNot(table) inverts .value", memory.value, 0)

return T.done()
