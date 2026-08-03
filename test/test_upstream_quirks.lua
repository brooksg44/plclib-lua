-- Deliberate fidelity to upstream quirks.
--
-- orNotBit, output and outputNot test "scanValue == 1" rather than "scanValue
-- is non-zero", unlike andBit/andNotBit/orBit/xorBit. That looks like an
-- inconsistency, and it does make those three read an un-normalised analog
-- value as off. But the C source has exactly this code, and this port
-- reproduces upstream behaviour rather than silently correcting it.
--
-- This suite exists so that "fixing" them fails the tests. If you decide to
-- diverge from upstream on purpose, change these expectations in the same
-- commit and say why.
--
-- Upstream, plcLib.cpp:
--     unsigned int orNotBit(int input) {
--         if (scanValue == 1) {
--         }
--         else {
--             if (digitalRead(input) == 0) { scanValue = 1; }
--             else                         { scanValue = 0; }
--         }
--         return(scanValue);
--     }

package.path = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or ".")
               .. "/?.lua;" .. package.path
local T = require("helper")
local plcLib = T.plcLib

local pins, written = T.mockHAL()

T.section("orNotBit truth table on {0,1} is correct OR-NOT")
for _, c in ipairs({{0,0,1}, {0,1,0}, {1,0,1}, {1,1,1}}) do
    local sv, input, want = c[1], c[2], c[3]
    plcLib.scanValue = sv
    T.check(string.format("scanValue=%d orNotBit(%d)", sv, input),
            plcLib.orNotBit(input), want)
end

T.section("orNotBit keeps upstream's scanValue == 1 guard")
plcLib.scanValue = 512
T.check("512 orNotBit(1) -> 0, not 1", plcLib.orNotBit(1), 0)
plcLib.scanValue = 512
T.check("512 orNotBit(0) -> 1", plcLib.orNotBit(0), 1)

T.section("output/outputNot keep upstream's scanValue == 1 guard")
plcLib.scanValue = 1
plcLib.output("Y")
T.check("scanValue=1 energises the coil", written["Y"], 1)
plcLib.scanValue = 0
plcLib.output("Y")
T.check("scanValue=0 de-energises the coil", written["Y"], 0)
plcLib.scanValue = 512
plcLib.output("Y")
T.check("scanValue=512 reads as off, per upstream", written["Y"], 0)

plcLib.scanValue = 1
plcLib.outputNot("Z")
T.check("outputNot with scanValue=1", written["Z"], 0)
plcLib.scanValue = 0
plcLib.outputNot("Z")
T.check("outputNot with scanValue=0", written["Z"], 1)
plcLib.scanValue = 512
plcLib.outputNot("Z")
T.check("outputNot with scanValue=512, per upstream", written["Z"], 1)

T.section("table reference branch follows the same guard")
local ref = {value = -1}
plcLib.scanValue = 512
plcLib.output(ref)
T.check("output(table) with scanValue=512", ref.value, 0)
plcLib.scanValue = 1
plcLib.output(ref)
T.check("output(table) with scanValue=1", ref.value, 1)

T.section("outputs pass scanValue through unchanged")
-- Normalising here would break outputPWM, which needs the full 0..1023 range.
plcLib.scanValue = 512
T.check("output returns scanValue", plcLib.output("D"), 512)
T.check("scanValue survives output", plcLib.scanValue, 512)
plcLib.outputPWM("E")
T.check("outputPWM after output writes 512/4", written["E"], 128)
plcLib.scanValue = 1023
plcLib.outputNot("F")
T.check("scanValue survives outputNot", plcLib.scanValue, 1023)
plcLib.outputPWM("G")
T.check("outputPWM after outputNot writes 1023/4", written["G"], 255)

T.section("inputNot matches upstream's input == 1 test")
-- Upstream: if (input == 1) scanValue = 0; else scanValue = 1;
T.check("inputNot(1) -> 0", plcLib.inputNot(1), 0)
T.check("inputNot(0) -> 1", plcLib.inputNot(0), 1)
T.check("inputNot(512) -> 1, per upstream", plcLib.inputNot(512), 1)

T.section("the documented normalisation route works")
pins["A0"] = 512
plcLib.inputAnalog(plcLib.X0)
T.check("inputAnalog leaves the raw value", plcLib.scanValue, 512)
plcLib.compareGT(500)
T.check("compareGT(500) normalises to 1", plcLib.scanValue, 1)
plcLib.output(plcLib.Y0)
T.check("normalised value drives the coil", written["3"], 1)

return T.done()
