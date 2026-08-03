-- Executes every snippet in the README's API Reference, so the documented
-- surface cannot drift from the library. This is also the only coverage the
-- Counter, Shift, Stack and Pulse classes have.
--
-- Those classes follow one convention: their methods take no arguments, they
-- read plcLib.scanValue for input, and several write their result back into it
-- rather than returning it.

package.path = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or ".")
               .. "/?.lua;" .. package.path
local T = require("helper")
local plcLib = T.plcLib

local function ck(l, g, w) T.check(l, g, w) end
local function guarded(label, fn)
    T.section(label)
    local ok, err = pcall(fn)
    if not ok then T.check(label .. " ran without error", tostring(err), true) end
end

-- The clock starts at 1000, not 0: a timer whose start time is exactly 0 is
-- treated as not started and restarts on every scan. See the README.
local pins, written, clock = {}, {}, 1000
plcLib.setHAL({
    digitalRead  = function(p) return pins[tostring(p)] or 0 end,
    digitalWrite = function(p, v) written[tostring(p)] = v end,
    analogRead   = function(p) return pins[tostring(p)] or 0 end,
    analogWrite  = function(p, v) written[tostring(p)] = v end,
    pinMode      = function() end,
    millis       = function() return clock end,
})

guarded("setup", function()
    plcLib.setupPLC()
    ck("VERSION", plcLib.VERSION, "1.4.0")
    plcLib.scanValue = 1
    ck("scanValue is writable", plcLib.scanValue, 1)
end)

guarded("timers", function()
    local t1 = {value = 0}
    clock = 1000
    pins["A0"] = 1
    plcLib.input(plcLib.X0)
    ck("timerOn not yet elapsed", plcLib.timerOn(t1, 2000), 0)
    clock = 4000
    plcLib.input(plcLib.X0)
    ck("timerOn elapsed", plcLib.timerOn(t1, 2000), 1)
    plcLib.output(plcLib.Y0)
    ck("timer drove Y0", written["3"], 1)

    local t2 = {value = 0}
    plcLib.input(plcLib.X0)
    plcLib.timerOff(t2, 2000)
    local t3 = {value = 0}
    plcLib.input(plcLib.X0)
    plcLib.timerPulse(t3, 2000)
    local t4, t5 = {value = 0}, {value = 0}
    plcLib.input(plcLib.X0)
    plcLib.timerCycle(t4, 500, t5, 500)
end)

guarded("comparison", function()
    pins["A0"] = 700
    plcLib.inputAnalog(plcLib.X0)
    ck("compareGT above", plcLib.compareGT(500), 1)
    plcLib.inputAnalog(plcLib.X0)
    ck("compareLT above", plcLib.compareLT(500), 0)
    pins["A0"] = 300
    plcLib.inputAnalog(plcLib.X0)
    ck("compareGT below", plcLib.compareGT(500), 0)
end)

guarded("latch/set/reset", function()
    pins["A0"], pins["A1"], pins["A2"] = 1, 0, 0
    local y = {value = 0}
    plcLib.input(plcLib.X0)
    plcLib.latch(y, plcLib.X1)
    ck("latch sets", y.value, 1)
    plcLib.input(0)
    plcLib.latch(y, plcLib.X1)
    ck("latch holds", y.value, 1)
    plcLib.input(0)
    pins["A1"] = 1
    plcLib.latch(y, plcLib.X1)
    ck("latch resets", y.value, 0)

    local z = {value = 0}
    plcLib.input(1)
    plcLib.set(z)
    ck("set latches on", z.value, 1)
    plcLib.input(1)
    plcLib.reset(z)
    ck("reset clears", z.value, 0)
end)

guarded("counter", function()
    local counter = plcLib.Counter(10, 0)
    ck("presetValue", counter:presetValue(), 10)
    ck("count starts at 0", counter:count(), 0)
    for _ = 1, 3 do
        plcLib.input(1); counter:countUp()
        plcLib.input(0); counter:countUp()
    end
    ck("counted up three times", counter:count(), 3)
    plcLib.input(1); counter:countDown()
    ck("counted down once", counter:count(), 2)
    ck("upperQ returns a value", counter:upperQ(), 0)
    ck("upperQ also loads scanValue", plcLib.scanValue, 0)
    ck("lowerQ returns a value", counter:lowerQ(), 0)
    plcLib.input(1); counter:preset()
    plcLib.input(1); counter:clear()
    ck("clear returns to 0", counter:count(), 0)
end)

guarded("shift register", function()
    local shift = plcLib.Shift(0)
    ck("value starts at 0", shift:value(), 0)
    for _, bit in ipairs({1, 0, 1, 1}) do
        plcLib.input(bit);  shift:inputBit()
        plcLib.input(1);    shift:shiftLeft()
        plcLib.input(0);    shift:shiftLeft()
    end
    ck("shifted in 1,0,1,1", shift:value(), 11)
    ck("bitValue returns the bit", shift:bitValue(0), 1)
    ck("bitValue also loads scanValue", plcLib.scanValue, 1)
    ck("bitValue of a clear bit", shift:bitValue(2), 0)
    plcLib.input(1); shift:reset()
    ck("reset clears the register", shift:value(), 0)
    plcLib.input(1); shift:shiftRight()
end)

guarded("stack", function()
    local stack = plcLib.Stack()
    plcLib.input(1); stack:push()
    plcLib.input(1); stack:andBlock()
    ck("andBlock of 1 and 1", plcLib.scanValue, 1)
    -- 1 AND 1 and 1 OR 1 are both 1, so the case above does not actually show
    -- that andBlock ANDs. These mixed cases do.
    plcLib.input(1); stack:push()
    plcLib.input(0); stack:andBlock()
    ck("andBlock of 0 and 1 is 0", plcLib.scanValue, 0)
    plcLib.input(0); stack:push()
    plcLib.input(1); stack:andBlock()
    ck("andBlock of 1 and 0 is 0", plcLib.scanValue, 0)
    plcLib.input(1); stack:push()
    plcLib.input(0); stack:orBlock()
    ck("orBlock of 0 and 1", plcLib.scanValue, 1)
    plcLib.input(0); stack:push()
    plcLib.input(0); stack:orBlock()
    ck("orBlock of 0 and 0 is 0", plcLib.scanValue, 0)
    plcLib.input(1); stack:push()
    stack:pop()
    ck("pop writes the accumulator", plcLib.scanValue, 1)
    plcLib.input(0); stack:push()
    stack:pop()
    ck("pop of a pushed 0", plcLib.scanValue, 0)

    -- The register is shifted left on every pop/andBlock/orBlock. Without a
    -- mask it grows past 32 bits and the top-bit test stays true forever, so
    -- everything reports 1 no matter what was pushed. Only repeated use shows
    -- it: the first couple of operations look correct either way.
    local deep = plcLib.Stack()
    for i = 1, 20 do
        plcLib.input(0); deep:push()
        deep:pop()
        ck("deep stack, pushed 0, round " .. i, plcLib.scanValue, 0)
    end
    ck("register stayed within 32 bits", deep._sreg <= 0xFFFFFFFF, true)
end)

guarded("pulse", function()
    local pulse = plcLib.Pulse()
    plcLib.input(0); pulse:inClock()
    plcLib.input(1); pulse:inClock()
    pulse:rising()
    ck("rising leaves 1 in scanValue", plcLib.scanValue, 1)
    ck("rising itself returns nothing", pulse:rising(), nil)
    plcLib.input(1); pulse:inClock()
    pulse:rising()
    ck("no edge on a steady input", plcLib.scanValue, 0)
    plcLib.input(0); pulse:inClock()
    pulse:falling()
    ck("falling leaves 1 in scanValue", plcLib.scanValue, 1)
    ck("falling itself returns nothing", pulse:falling(), nil)
end)

guarded("complete rung", function()
    pins["A0"], pins["A1"], pins["A2"], pins["A3"] = 1, 0, 0, 700
    plcLib.input(plcLib.X0)
    plcLib.andNotBit(plcLib.X1)
    plcLib.latch(plcLib.Y0, plcLib.X2)
    ck("rung latched Y0", written["3"], 1)
    plcLib.inputAnalog(plcLib.X3)
    plcLib.compareGT(500)
    plcLib.output(plcLib.Y1)
    ck("analog rung drove Y1", written["5"], 1)
end)

return T.done()
