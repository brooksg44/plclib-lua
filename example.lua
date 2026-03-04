#!/usr/bin/env lua
--[[
  plcLib Example
  
  This example demonstrates basic usage of the plcLib Lua library
]]

-- Add the plcLib path to Lua's search path
package.path = package.path .. ";/Users/gregorybrooks/Lua/?.lua;/Users/gregorybrooks/Lua/?/?.lua"

local plcLib = require("plcLib.plcLib")

print("plcLib Version: " .. plcLib.VERSION)
print("=" .. string.rep("=", 50))

-- Example 1: Simple mock HAL for demonstration
print("\n1. Setting up mock Hardware Abstraction Layer")

local mockInputs = {
    ["A0"] = 1,
    ["A1"] = 0,
    ["A2"] = 1,
    ["A3"] = 0
}

local mockOutputs = {}

plcLib.setHAL({
    digitalRead = function(pin)
        return mockInputs[tostring(pin)] or 0
    end,
    
    digitalWrite = function(pin, value)
        mockOutputs[tostring(pin)] = value
        print("   Output " .. tostring(pin) .. " = " .. value)
    end,
    
    analogRead = function(pin)
        return (mockInputs[tostring(pin)] or 0) * 1023
    end,
    
    analogWrite = function(pin, value)
        mockOutputs[tostring(pin)] = value
        print("   PWM Output " .. tostring(pin) .. " = " .. value)
    end,
    
    pinMode = function(pin, mode)
        print("   Pin " .. tostring(pin) .. " set to mode " .. tostring(mode))
    end,
    
    millis = function()
        return os.clock() * 1000
    end
})

print("   HAL configured!")

-- Example 2: Basic I/O
print("\n2. Basic Digital I/O")
plcLib.input(plcLib.X0)  -- Read X0 (A0)
print("   Input X0 (A0) = " .. plcLib.scanValue)
plcLib.output(plcLib.Y0)  -- Write to Y0 (pin 3)

-- Example 3: Logic operations
print("\n3. Logic Operations (AND)")
plcLib.input(1)  -- Start with 1
plcLib.andBit(1)  -- AND with 1
print("   1 AND 1 = " .. plcLib.scanValue)

plcLib.input(1)
plcLib.andBit(0)
print("   1 AND 0 = " .. plcLib.scanValue)

-- Example 4: OR operation
print("\n4. Logic Operations (OR)")
plcLib.input(0)
plcLib.orBit(1)
print("   0 OR 1 = " .. plcLib.scanValue)

-- Example 5: XOR operation
print("\n5. Logic Operations (XOR)")
plcLib.input(1)
plcLib.xorBit(1)
print("   1 XOR 1 = " .. plcLib.scanValue)

plcLib.input(1)
plcLib.xorBit(0)
print("   1 XOR 0 = " .. plcLib.scanValue)

-- Example 6: Comparison operations
print("\n6. Comparison Operations")
plcLib.inputAnalog(500)
plcLib.compareGT(400)
print("   500 > 400 = " .. plcLib.scanValue)

plcLib.inputAnalog(300)
plcLib.compareLT(400)
print("   300 < 400 = " .. plcLib.scanValue)

-- Example 7: Counter
print("\n7. Counter Example (Up Counter)")
local counter = plcLib.Counter(5, 0)  -- Count up to 5

print("   Counting up to 5:")
for i = 1, 7 do
    -- Rising edge: set clock high
    plcLib.input(1)
    counter:countUp()
    print("   Count = " .. counter:count() .. ", upperQ = " .. counter:upperQ())
    
    -- Falling edge: set clock low for next cycle
    plcLib.input(0)
    counter:countUp()  -- Call again to register the low state
end

-- Example 8: Shift Register
print("\n8. Shift Register Example")
local shifter = plcLib.Shift(0)

print("   Shifting in pattern 1,0,1,1:")
local pattern = {1, 0, 1, 1}
for _, bit in ipairs(pattern) do
    -- Set the input bit
    plcLib.input(bit)
    shifter:inputBit()
    
    -- Rising edge: clock high to shift
    plcLib.input(1)
    shifter:shiftLeft()
    print("   Shifted in " .. bit .. ", Register value = " .. shifter:value())
    
    -- Falling edge: clock low for next cycle
    plcLib.input(0)
    shifter:shiftLeft()  -- Call again to register the low state
end

-- Example 9: Timer (simulated)
print("\n9. Timer Example (On-delay)")
local timer = {value = 0}
local startTime = plcLib.hal.millis()

print("   Testing timer with 100ms delay:")
for i = 1, 3 do
    plcLib.input(1)  -- Enable timer
    plcLib.timerOn(timer, 100)  -- 100ms delay
    print("   Time: " .. math.floor(plcLib.hal.millis() - startTime) .. "ms, Timer output = " .. plcLib.scanValue)
    
    -- Simulate time passing
    local function sleep(ms)
        local target = os.clock() + ms/1000
        while os.clock() < target do end
    end
    sleep(50)
end

-- Example 10: Pulse (edge detection)
print("\n10. Pulse Edge Detection")
local pulse = plcLib.Pulse()

print("   Testing rising and falling edges:")
local signals = {0, 1, 1, 0, 0, 1}
for _, sig in ipairs(signals) do
    plcLib.input(sig)
    pulse:inClock()
    pulse:rising()
    local rising = plcLib.scanValue
    pulse:falling()
    local falling = plcLib.scanValue
    print("   Signal = " .. sig .. ", Rising = " .. rising .. ", Falling = " .. falling)
end

-- Example 11: Latch
print("\n11. Latch (Set-Reset)")
local latchOutput = {value = 0}

print("   Set latch:")
plcLib.input(1)  -- Set signal
plcLib.latch(latchOutput, 0)  -- Reset = 0
print("   Latch output = " .. latchOutput.value)

print("   Hold latch (both inputs low):")
plcLib.input(0)  -- Set signal = 0
plcLib.latch(latchOutput, 0)  -- Reset = 0
print("   Latch output = " .. latchOutput.value)

print("   Reset latch:")
plcLib.input(0)  -- Set signal = 0
plcLib.latch(latchOutput, 1)  -- Reset = 1
print("   Latch output = " .. latchOutput.value)

print("\n" .. string.rep("=", 50))
print("Examples complete!")
