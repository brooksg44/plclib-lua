--[[
  plcLib Version 1.4.0, last updated 1 October, 2017.
  Converted to Lua
  
  A simple Programmable Logic Controller (PLC) library
  Originally for Arduino and compatibles, converted to Lua.

  Original Author:    W. Ditch
                      https://github.com/wditch/plcLib

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details, available from:
  <http://www.gnu.org/licenses/>
]]

local plcLib = {}

-- Module metadata
plcLib.VERSION = "1.4.0"
plcLib.appName = "plcLib"
plcLib.appMajorVersion = '1'
plcLib.appMinorVersion = '4'

-- Global scan value (stores intermediate results)
plcLib.scanValue = 0

-- Pin identifiers are strings, plain values are numbers.
--
-- The Arduino original distinguishes these with C++ overloads: in(int) reads a
-- pin via digitalRead(), while in(unsigned int) takes the argument as a value
-- (used to read back a memory bit previously written with out(&bit)).  Lua has
-- a single number type, so the two overloads are selected by Lua type instead:
--
--     plcLib.input(plcLib.X0)  -- string -> in(int)          -> digitalRead
--     plcLib.input(myBit)      -- number -> in(unsigned int) -> value
--
-- Every pin constant must therefore be a string, or it is taken as a value.
-- The HAL receives these identifiers verbatim and maps them to the platform.

-- Define basic I/O pins for Arduino Uno and compatibles
plcLib.X0 = "A0"
plcLib.X1 = "A1"
plcLib.X2 = "A2"
plcLib.X3 = "A3"

plcLib.Y0 = "3"
plcLib.Y1 = "5"
plcLib.Y2 = "6"
plcLib.Y3 = "9"

-- Define Motor Shield pin names
plcLib.DIRA = "12"
plcLib.DIRB = "13"
plcLib.PWMA = "3"
plcLib.PWMB = "11"
plcLib.BRAKEA = "9"
plcLib.BRAKEB = "8"
plcLib.CURRENTA = "A0"
plcLib.CURRENTB = "A1"

-- Additional I/O pins for Mega variants (can be extended)
plcLib.X4 = "A6"
plcLib.X5 = "A7"
plcLib.X6 = "A8"
plcLib.X7 = "A9"
plcLib.Y4 = "4"
plcLib.Y5 = "7"
plcLib.Y6 = "8"
plcLib.Y7 = "12"

-- Hardware abstraction layer (to be implemented by user for specific platform)
plcLib.hal = {
    digitalRead = function(pin) return 0 end,
    digitalWrite = function(pin, value) end,
    analogRead = function(pin) return 0 end,
    analogWrite = function(pin, value) end,
    pinMode = function(pin, mode) end,
    millis = function() return os.clock() * 1000 end
}

-- Set the hardware abstraction layer
function plcLib.setHAL(hal)
    plcLib.hal = hal
end

-- Setup PLC (initialize pins)
function plcLib.setupPLC()
    -- This should be implemented based on the specific hardware platform
    -- For Arduino, would set pin modes
    -- For now, this is a placeholder
end

-- Read an input pin or variable
function plcLib.input(input)
    if type(input) == "number" then
        plcLib.scanValue = input
    elseif type(input) == "string" then
        plcLib.scanValue = plcLib.hal.digitalRead(input)
    else
        plcLib.scanValue = plcLib.hal.digitalRead(input)
    end
    return plcLib.scanValue
end

-- Alias for input
plcLib.i = plcLib.input

-- Read an inverted input
function plcLib.inputNot(input)
    if type(input) == "number" then
        plcLib.scanValue = (input == 1) and 0 or 1
    elseif type(input) == "string" then
        local val = plcLib.hal.digitalRead(input)
        plcLib.scanValue = (val == 1) and 0 or 1
    else
        local val = plcLib.hal.digitalRead(input)
        plcLib.scanValue = (val == 1) and 0 or 1
    end
    return plcLib.scanValue
end

-- Read an analog input
function plcLib.inputAnalog(input)
    if type(input) == "number" then
        plcLib.scanValue = input
    else
        plcLib.scanValue = plcLib.hal.analogRead(input)
    end
    return plcLib.scanValue
end

-- Output to a pin or variable
function plcLib.output(output)
    if type(output) == "table" then
        -- Output to a reference (table with value)
        output.value = (plcLib.scanValue == 1) and 1 or 0
    else
        -- Output to a pin
        if plcLib.scanValue == 1 then
            plcLib.hal.digitalWrite(output, 1)
        else
            plcLib.hal.digitalWrite(output, 0)
        end
    end
    return plcLib.scanValue
end

-- Alias for output
plcLib.o = plcLib.output

-- Inverted output
function plcLib.outputNot(output)
    if type(output) == "table" then
        output.value = (plcLib.scanValue == 1) and 0 or 1
    else
        if plcLib.scanValue == 1 then
            plcLib.hal.digitalWrite(output, 0)
        else
            plcLib.hal.digitalWrite(output, 1)
        end
    end
    return plcLib.scanValue
end

-- PWM output (scanValue in range 0-1023)
function plcLib.outputPWM(output)
    plcLib.hal.analogWrite(output, math.floor(plcLib.scanValue / 4))
    return plcLib.scanValue
end

-- Bitwise helpers.
--
-- The Arduino original combines scanValue with the input using C bitwise
-- operators on unsigned int (scanValue & input, | , ^ , & ~input), not logical
-- operators, so the port must do the same to agree on non-boolean scan values.
-- The 5.3+ bitwise operators are avoided deliberately: they are a parse error
-- on Lua 5.1/5.2, which the rest of this file still supports via bit32.
--
-- Every operation is derived from AND, which keeps them independent of integer
-- width -- notably "a & ~b" is exactly "a minus the bits a and b share", so it
-- needs no assumption about sizeof(unsigned int) on the target.
local function bitAnd(a, b)
    if bit32 then return bit32.band(a, b) end
    local result, place = 0, 1
    a, b = math.floor(a), math.floor(b)
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then result = result + place end
        a, b = math.floor(a / 2), math.floor(b / 2)
        place = place * 2
    end
    return result
end

local function bitOr(a, b)      return a + b - bitAnd(a, b) end
local function bitXor(a, b)     return a + b - 2 * bitAnd(a, b) end
local function bitAndNot(a, b)  return a - bitAnd(a, b) end

-- AND scanValue with input
function plcLib.andBit(input)
    if type(input) == "number" then
        plcLib.scanValue = bitAnd(plcLib.scanValue, input)
    else
        local val = plcLib.hal.digitalRead(input)
        plcLib.scanValue = bitAnd(plcLib.scanValue, val)
    end
    return plcLib.scanValue
end

-- AND scanValue with inverted input
function plcLib.andNotBit(input)
    if type(input) == "number" then
        plcLib.scanValue = bitAndNot(plcLib.scanValue, input)
    else
        local val = plcLib.hal.digitalRead(input)
        plcLib.scanValue = bitAndNot(plcLib.scanValue, val)
    end
    return plcLib.scanValue
end

-- OR scanValue with input
function plcLib.orBit(input)
    if type(input) == "number" then
        plcLib.scanValue = bitOr(plcLib.scanValue, input)
    else
        local val = plcLib.hal.digitalRead(input)
        plcLib.scanValue = bitOr(plcLib.scanValue, val)
    end
    return plcLib.scanValue
end

-- OR scanValue with inverted input
function plcLib.orNotBit(input)
    if plcLib.scanValue == 1 then
        -- scanValue is already 1, stays 1
    else
        if type(input) == "number" then
            plcLib.scanValue = (input == 0) and 1 or 0
        else
            local val = plcLib.hal.digitalRead(input)
            plcLib.scanValue = (val == 0) and 1 or 0
        end
    end
    return plcLib.scanValue
end

-- XOR scanValue with input
function plcLib.xorBit(input)
    if type(input) == "number" then
        plcLib.scanValue = bitXor(plcLib.scanValue, input)
    else
        local val = plcLib.hal.digitalRead(input)
        plcLib.scanValue = bitXor(plcLib.scanValue, val)
    end
    return plcLib.scanValue
end

-- Set - Reset latch
function plcLib.latch(output, reset)
    local outputVal
    if type(output) == "table" then
        outputVal = output.value or 0
    else
        outputVal = plcLib.hal.digitalRead(output)
    end
    
    local resetVal
    if type(reset) == "number" then
        resetVal = reset
    elseif type(reset) == "table" then
        resetVal = reset.value or 0
    else
        resetVal = plcLib.hal.digitalRead(reset)
    end
    
    -- Self latch by ORing with Output
    plcLib.scanValue = (plcLib.scanValue ~= 0 or outputVal ~= 0) and 1 or 0
    -- AND-Not with Reset
    plcLib.scanValue = (plcLib.scanValue ~= 0 and resetVal == 0) and 1 or 0
    
    if type(output) == "table" then
        output.value = plcLib.scanValue
    else
        if plcLib.scanValue == 1 then
            plcLib.hal.digitalWrite(output, 1)
        else
            plcLib.hal.digitalWrite(output, 0)
        end
    end
    
    return plcLib.scanValue
end

-- On delay timer
function plcLib.timerOn(timerState, timerPeriod)
    if plcLib.scanValue == 0 then
        timerState.value = 0
    else
        if timerState.value == 0 then
            timerState.value = plcLib.hal.millis()
            plcLib.scanValue = 0
        else
            if plcLib.hal.millis() - timerState.value >= timerPeriod then
                plcLib.scanValue = 1
            else
                plcLib.scanValue = 0
            end
        end
    end
    return plcLib.scanValue
end

-- Pulse timer
function plcLib.timerPulse(timerState, timerPeriod)
    if plcLib.scanValue == 1 or timerState.value ~= 0 then
        if timerState.value == 0 then
            timerState.value = plcLib.hal.millis()
            plcLib.scanValue = 1
        else
            if plcLib.hal.millis() - timerState.value >= timerPeriod then
                if plcLib.scanValue == 0 then
                    timerState.value = 0
                    plcLib.scanValue = 0
                else
                    plcLib.scanValue = 0
                end
            else
                plcLib.scanValue = 1
            end
        end
    end
    return plcLib.scanValue
end

-- Off delay timer
function plcLib.timerOff(timerState, timerPeriod)
    if plcLib.scanValue == 0 then
        if timerState.value == 0 then
            -- Do nothing
        else
            if plcLib.hal.millis() - timerState.value >= timerPeriod then
                plcLib.scanValue = 0
            else
                plcLib.scanValue = 1
            end
        end
    else
        timerState.value = plcLib.hal.millis()
    end
    return plcLib.scanValue
end

-- Cycle timer
function plcLib.timerCycle(timer1State, timer1Period, timer2State, timer2Period)
    if plcLib.scanValue == 0 then
        timer2State.value = 0
        timer1State.value = 1
    else
        if timer2State.value == 0 then
            if timer1State.value == 1 then
                timer1State.value = plcLib.hal.millis()
            elseif plcLib.hal.millis() - timer1State.value >= timer1Period then
                timer1State.value = 0
                timer2State.value = 1
            end
            plcLib.scanValue = 0
        end
        
        if timer1State.value == 0 then
            if timer2State.value == 1 then
                timer2State.value = plcLib.hal.millis()
            elseif plcLib.hal.millis() - timer2State.value >= timer2Period then
                timer2State.value = 0
                timer1State.value = 1
            end
            plcLib.scanValue = 1
        end
    end
    return plcLib.scanValue
end

-- Compare greater than
function plcLib.compareGT(input)
    if type(input) == "number" then
        plcLib.scanValue = (plcLib.scanValue > input) and 1 or 0
    else
        local val = plcLib.hal.analogRead(input)
        plcLib.scanValue = (plcLib.scanValue > val) and 1 or 0
    end
    return plcLib.scanValue
end

-- Compare less than
function plcLib.compareLT(input)
    if type(input) == "number" then
        plcLib.scanValue = (plcLib.scanValue < input) and 1 or 0
    else
        local val = plcLib.hal.analogRead(input)
        plcLib.scanValue = (plcLib.scanValue < val) and 1 or 0
    end
    return plcLib.scanValue
end

-- Set a latched output
function plcLib.set(output)
    if type(output) == "table" then
        local outputVal = output.value or 0
        plcLib.scanValue = (plcLib.scanValue ~= 0 or outputVal ~= 0) and 1 or 0
        if plcLib.scanValue == 1 then
            output.value = 1
        end
    else
        local outputVal = plcLib.hal.digitalRead(output)
        plcLib.scanValue = (plcLib.scanValue ~= 0 or outputVal ~= 0) and 1 or 0
        if plcLib.scanValue == 1 then
            plcLib.hal.digitalWrite(output, 1)
        end
    end
    return plcLib.scanValue
end

-- Reset (clear) a latched output
function plcLib.reset(output)
    if plcLib.scanValue == 1 then
        if type(output) == "table" then
            output.value = 0
        else
            plcLib.hal.digitalWrite(output, 0)
        end
    end
    return plcLib.scanValue
end

-- Counter class
local Counter = {}
Counter.__index = Counter

function plcLib.Counter(presetValue, direction)
    local self = setmetatable({}, Counter)
    self._pv = presetValue or 0
    direction = direction or 0
    
    if direction == 0 then
        self._ct = 0
        self._uQ = 0
        self._lQ = 1
    else
        self._ct = self._pv
        self._uQ = 1
        self._lQ = 0
    end
    
    self._ctUpEdge = 0
    self._ctDownEdge = 0
    
    return self
end

function Counter:presetValue()
    return self._pv
end

function Counter:clear()
    if plcLib.scanValue == 1 then
        self._ct = 0
        self._uQ = 0
        self._lQ = 1
        self._ctUpEdge = 0
        self._ctDownEdge = 0
    end
end

function Counter:preset()
    if plcLib.scanValue == 1 then
        self._ct = self._pv
        self._uQ = 1
        self._lQ = 0
        self._ctUpEdge = 0
        self._ctDownEdge = 0
    end
end

function Counter:upperQ()
    plcLib.scanValue = self._uQ
    return self._uQ
end

function Counter:lowerQ()
    plcLib.scanValue = self._lQ
    return self._lQ
end

function Counter:count()
    return self._ct
end

function Counter:countUp()
    if plcLib.scanValue == 0 then
        self._ctUpEdge = 0
    else
        if self._ctUpEdge == 0 and self._ct ~= self._pv then
            self._ctUpEdge = 1
            self._ct = self._ct + 1
            if self._ct == self._pv then
                self._uQ = 1
                self._lQ = 0
            elseif self._ct ~= self._pv then
                self._uQ = 0
                self._lQ = 0
            end
        end
    end
end

function Counter:countDown()
    if plcLib.scanValue == 0 then
        self._ctDownEdge = 0
    else
        if self._ctDownEdge == 0 and self._ct ~= 0 then
            self._ctDownEdge = 1
            self._ct = self._ct - 1
            if self._ct == 0 then
                self._uQ = 0
                self._lQ = 1
            elseif self._ct ~= 0 then
                self._uQ = 0
                self._lQ = 0
            end
        end
    end
end

-- Shift register class
local Shift = {}
Shift.__index = Shift

function plcLib.Shift(initialValue)
    local self = setmetatable({}, Shift)
    self._sreg = initialValue or 0
    self._srLeftEdge = 0
    self._srRightEdge = 0
    self._inbit = 0
    return self
end

function Shift:bitValue(bitno)
    local mask = bit32 and bit32.lshift(1, bitno) or (2 ^ bitno)
    plcLib.scanValue = (bit32 and bit32.band(self._sreg, mask) or (self._sreg % (2 * mask) >= mask)) and 1 or 0
    return plcLib.scanValue
end

function Shift:value()
    return self._sreg
end

function Shift:reset()
    if plcLib.scanValue == 1 then
        self._sreg = 0
        self._srLeftEdge = 0
        self._srRightEdge = 0
    end
end

function Shift:inputBit()
    if plcLib.scanValue == 0 then
        self._inbit = 0
    else
        self._inbit = 1
    end
end

function Shift:shiftRight()
    if plcLib.scanValue == 0 then
        self._srRightEdge = 0
    else
        if self._srRightEdge == 0 then
            self._srRightEdge = 1
            self._sreg = bit32 and bit32.rshift(self._sreg, 1) or math.floor(self._sreg / 2)
            if self._inbit == 1 then
                self._sreg = bit32 and bit32.bor(self._sreg, 0x8000) or (self._sreg + 32768)
            end
        end
    end
end

function Shift:shiftLeft()
    if plcLib.scanValue == 0 then
        self._srLeftEdge = 0
    else
        if self._srLeftEdge == 0 then
            self._srLeftEdge = 1
            self._sreg = bit32 and bit32.lshift(self._sreg, 1) or (self._sreg * 2)
            -- Mask to keep within 16-bit range (like Arduino)
            self._sreg = bit32 and bit32.band(self._sreg, 0xFFFF) or (self._sreg % 65536)
            if self._inbit == 1 then
                self._sreg = bit32 and bit32.bor(self._sreg, 1) or (self._sreg + 1)
            end
        end
    end
end

-- Stack class
local Stack = {}
Stack.__index = Stack

function plcLib.Stack()
    local self = setmetatable({}, Stack)
    self._sreg = 0
    return self
end

function Stack:push()
    self._sreg = bit32 and bit32.rshift(self._sreg, 1) or math.floor(self._sreg / 2)
    if plcLib.scanValue == 1 then
        self._sreg = bit32 and bit32.bor(self._sreg, 0x80000000) or (self._sreg + 2147483648)
    end
end

function Stack:pop()
    local mask = 0x80000000
    plcLib.scanValue = (bit32 and bit32.band(self._sreg, mask) or (self._sreg >= mask)) and 1 or 0
    -- Mask back to 32 bits. bit32.lshift truncates for us, but the arithmetic
    -- fallback does not, and Lua 5.3+ has no bit32 so the fallback is the only
    -- path there. Without this _sreg grows without bound and the top-bit test
    -- below stays true forever, so pop/andBlock/orBlock report 1 whatever was
    -- pushed. Shift masks its own register for the same reason.
    self._sreg = bit32 and bit32.lshift(self._sreg, 1) or ((self._sreg * 2) % 4294967296)
end

function Stack:orBlock()
    local mask = 0x80000000
    local topBit = (bit32 and bit32.band(self._sreg, mask) or (self._sreg >= mask)) and 1 or 0
    plcLib.scanValue = (plcLib.scanValue ~= 0 or topBit ~= 0) and 1 or 0
    -- Mask back to 32 bits. bit32.lshift truncates for us, but the arithmetic
    -- fallback does not, and Lua 5.3+ has no bit32 so the fallback is the only
    -- path there. Without this _sreg grows without bound and the top-bit test
    -- below stays true forever, so pop/andBlock/orBlock report 1 whatever was
    -- pushed. Shift masks its own register for the same reason.
    self._sreg = bit32 and bit32.lshift(self._sreg, 1) or ((self._sreg * 2) % 4294967296)
end

function Stack:andBlock()
    local mask = 0x80000000
    local topBit = (bit32 and bit32.band(self._sreg, mask) or (self._sreg >= mask)) and 1 or 0
    plcLib.scanValue = (plcLib.scanValue ~= 0 and topBit ~= 0) and 1 or 0
    -- Mask back to 32 bits. bit32.lshift truncates for us, but the arithmetic
    -- fallback does not, and Lua 5.3+ has no bit32 so the fallback is the only
    -- path there. Without this _sreg grows without bound and the top-bit test
    -- below stays true forever, so pop/andBlock/orBlock report 1 whatever was
    -- pushed. Shift masks its own register for the same reason.
    self._sreg = bit32 and bit32.lshift(self._sreg, 1) or ((self._sreg * 2) % 4294967296)
end

-- Pulse class (edge detection)
local Pulse = {}
Pulse.__index = Pulse

function plcLib.Pulse()
    local self = setmetatable({}, Pulse)
    self._pulseInput = 0
    self._pulseUpEdge = 0
    self._pulseDownEdge = 0
    return self
end

function Pulse:inClock()
    if plcLib.scanValue ~= self._pulseInput then
        if plcLib.scanValue == 1 then
            self._pulseUpEdge = 1
            self._pulseDownEdge = 0
            self._pulseInput = 1
        else
            self._pulseUpEdge = 0
            self._pulseDownEdge = 1
            self._pulseInput = 0
        end
    else
        self._pulseUpEdge = 0
        self._pulseDownEdge = 0
    end
end

function Pulse:rising()
    plcLib.scanValue = self._pulseUpEdge
end

function Pulse:falling()
    plcLib.scanValue = self._pulseDownEdge
end

return plcLib
