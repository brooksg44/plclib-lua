-- Bitwise logic semantics.
--
-- The Arduino original computes scanValue & digitalRead(input), and likewise
-- | ^ and & ~input, on unsigned int. andNotBit uses the bitwise complement ~,
-- not the logical !, so 512 & ~1 is 512 rather than 0.
--
-- Bitwise and boolean logic agree on {0,1}, so ordinary ladder logic cannot
-- tell the difference. The distinction only shows once scanValue carries a
-- multi-bit value, i.e. between inputAnalog and compareGT/compareLT.

package.path = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or ".")
               .. "/?.lua;" .. package.path
local T = require("helper")
local plcLib = T.plcLib

T.mockHAL()

-- Native 5.3+ operators as the oracle, built with load() so this file still
-- parses on 5.1/5.2 (where the suite skips the comparison rather than failing).
local native = load([[
  return {
    band    = function(a,b) return a & b end,
    bor     = function(a,b) return a | b end,
    bxor    = function(a,b) return a ~ b end,
    bandnot = function(a,b) return a & ~b end,
  }
]])

local ops = {
    {"andBit",    plcLib.andBit,    "band"},
    {"andNotBit", plcLib.andNotBit, "bandnot"},
    {"orBit",     plcLib.orBit,     "bor"},
    {"xorBit",    plcLib.xorBit,    "bxor"},
}

if native then
    local ref = native()
    T.section("exhaustive agreement with C semantics, 0..255 x 0..255")
    for _, op in ipairs(ops) do
        local name, fn, oracle = op[1], op[2], ref[op[3]]
        local bad = 0
        for a = 0, 255 do
            for b = 0, 255 do
                plcLib.scanValue = a
                if fn(b) ~= oracle(a, b) then bad = bad + 1 end
            end
        end
        T.checkAll(name, bad, 65536)
    end

    T.section("analog range spot checks, 0..1023")
    local bad = 0
    for _, a in ipairs({0, 1, 2, 255, 256, 511, 512, 700, 1022, 1023}) do
        for _, b in ipairs({0, 1, 512, 1023}) do
            for _, op in ipairs(ops) do
                plcLib.scanValue = a
                if op[2](b) ~= ref[op[3]](a, b) then bad = bad + 1 end
            end
        end
    end
    T.checkAll("analog operand pairs", bad, 160)
else
    T.section("native bitwise oracle unavailable on this Lua, skipped")
end

-- The property that matters most: ordinary ladder logic is untouched.
T.section("digital truth tables match boolean logic")
local truth = {
    andBit    = function(s, i) return (s == 1 and i == 1) and 1 or 0 end,
    andNotBit = function(s, i) return (s == 1 and i == 0) and 1 or 0 end,
    orBit     = function(s, i) return (s == 1 or  i == 1) and 1 or 0 end,
    xorBit    = function(s, i) return (s ~= i) and 1 or 0 end,
}
for _, op in ipairs(ops) do
    for s = 0, 1 do
        for i = 0, 1 do
            plcLib.scanValue = s
            T.check(string.format("%s(%d) with scanValue=%d", op[1], i, s),
                    op[2](i), truth[op[1]](s, i))
        end
    end
end

T.section("documented behaviour on multi-bit scan values")
plcLib.scanValue = 512
T.check("512 andBit 1    -> 0",   plcLib.andBit(1), 0)
plcLib.scanValue = 512
T.check("512 andNotBit 1 -> 512", plcLib.andNotBit(1), 512)
plcLib.scanValue = 512
T.check("512 orBit 1     -> 513", plcLib.orBit(1), 513)
plcLib.scanValue = 512
T.check("512 xorBit 1    -> 513", plcLib.xorBit(1), 513)

T.section("pin overload takes the same bitwise path")
local pins = select(1, T.mockHAL())
pins["A0"] = 1
plcLib.scanValue = 512
T.check("512 andBit(X0), A0 high -> 0",   plcLib.andBit(plcLib.X0), 0)
plcLib.scanValue = 512
T.check("512 orBit(X0),  A0 high -> 513", plcLib.orBit(plcLib.X0), 513)

T.section("source avoids 5.3+ bitwise operators")
local src = assert(io.open(
    (debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or ".") .. "/../plcLib.lua")):read("a")
local stripped = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
T.check("no native & operator", stripped:find("[^&]&[^&]") == nil, true)
T.check("no native | operator", stripped:find("[^|]|[^|]") == nil, true)

return T.done()
