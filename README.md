# plcLib - Lua Version

A Programmable Logic Controller (PLC) library converted from Arduino C++ to Lua.

**Version:** 1.4.0  
**Original Author:** W. Ditch  
**GitHub:** https://github.com/wditch/plcLib

## Overview

This is a Lua conversion of the plcLib Arduino library. It provides PLC-style programming functions including:

- Digital and analog I/O operations
- Logic operations (AND, OR, XOR, NOT)
- Timers (On-delay, Off-delay, Pulse, Cycle)
- Counters (Up, Down, Up/Down)
- Shift registers
- Stack operations
- Latches and edge detection

## Installation

The library is already installed in `~/Lua/plcLib/`.

To use it in your Lua scripts:

```lua
local plcLib = require("plcLib.plcLib")
```

Or if you add `~/Lua` to your Lua path:

```lua
package.path = package.path .. ";/Users/gregorybrooks/Lua/?.lua;/Users/gregorybrooks/Lua/?/init.lua"
local plcLib = require("plcLib.plcLib")
```

## Hardware Abstraction Layer

Since Lua doesn't have direct hardware access like Arduino, you need to provide a Hardware Abstraction Layer (HAL) for your specific platform:

```lua
local plcLib = require("plcLib.plcLib")

-- Set up your hardware interface
plcLib.setHAL({
    digitalRead = function(pin) 
        -- Your implementation
        return 0 
    end,
    digitalWrite = function(pin, value) 
        -- Your implementation
    end,
    analogRead = function(pin) 
        -- Your implementation
        return 0 
    end,
    analogWrite = function(pin, value) 
        -- Your implementation
    end,
    pinMode = function(pin, mode) 
        -- Your implementation
    end,
    millis = function() 
        return os.clock() * 1000 
    end
})
```

## Basic Usage Examples

### Simple Digital I/O

```lua
local plcLib = require("plcLib.plcLib")

-- Read input and write to output
plcLib.input(plcLib.X0)    -- Read input X0
plcLib.output(plcLib.Y0)   -- Write to output Y0
```

### Logic Operations

```lua
-- AND operation
plcLib.input(plcLib.X0)
plcLib.andBit(plcLib.X1)
plcLib.output(plcLib.Y0)

-- OR operation
plcLib.input(plcLib.X0)
plcLib.orBit(plcLib.X1)
plcLib.output(plcLib.Y0)
```

### Timers

```lua
-- On-delay timer (2 second delay)
local timer1 = {value = 0}

plcLib.input(plcLib.X0)
plcLib.timerOn(timer1, 2000)  -- 2000ms = 2 seconds
plcLib.output(plcLib.Y0)
```

### Counters

```lua
-- Create an up counter with preset value of 10
local counter = plcLib.Counter(10, 0)

-- In your scan loop:
plcLib.input(clockSignal)
counter:countUp()

if counter:upperQ() == 1 then
    -- Counter has reached preset value
end
```

### Shift Register

```lua
-- Create a shift register
local shifter = plcLib.Shift(0)

-- Set input bit
plcLib.input(dataBit)
shifter:inputBit()

-- Shift left on clock signal
plcLib.input(clockSignal)
shifter:shiftLeft()
```

### Latch

```lua
-- Set-Reset latch
plcLib.input(setInput)
plcLib.latch(plcLib.Y0, resetInput)
```

## API Reference

### Input/Output Functions

- `plcLib.input(pin)` - Read digital input
- `plcLib.inputNot(pin)` - Read inverted digital input
- `plcLib.inputAnalog(pin)` - Read analog input
- `plcLib.output(pin)` - Write digital output
- `plcLib.outputNot(pin)` - Write inverted output
- `plcLib.outputPWM(pin)` - Write PWM output

### Logic Functions

- `plcLib.andBit(input)` - AND with scanValue
- `plcLib.andNotBit(input)` - AND NOT with scanValue
- `plcLib.orBit(input)` - OR with scanValue
- `plcLib.orNotBit(input)` - OR NOT with scanValue
- `plcLib.xorBit(input)` - XOR with scanValue

### Timer Functions

- `plcLib.timerOn(state, period)` - On-delay timer
- `plcLib.timerOff(state, period)` - Off-delay timer
- `plcLib.timerPulse(state, period)` - Pulse timer
- `plcLib.timerCycle(state1, period1, state2, period2)` - Cycle timer

### Comparison Functions

- `plcLib.compareGT(value)` - Greater than comparison
- `plcLib.compareLT(value)` - Less than comparison

### Latch Functions

- `plcLib.latch(output, reset)` - Set-Reset latch
- `plcLib.set(output)` - Set latched output
- `plcLib.reset(output)` - Reset latched output

### Counter Class

```lua
local counter = plcLib.Counter(presetValue, direction)
counter:countUp()
counter:countDown()
counter:clear()
counter:preset()
counter:upperQ()  -- Returns 1 when count reaches preset
counter:lowerQ()  -- Returns 1 when count reaches 0
counter:count()   -- Returns current count
```

### Shift Register Class

```lua
local shift = plcLib.Shift(initialValue)
shift:inputBit()
shift:shiftLeft()
shift:shiftRight()
shift:reset()
shift:bitValue(bitno)
shift:value()
```

### Stack Class

```lua
local stack = plcLib.Stack()
stack:push()
stack:pop()
stack:andBlock()
stack:orBlock()
```

### Pulse Class (Edge Detection)

```lua
local pulse = plcLib.Pulse()
pulse:inClock()
pulse:rising()   -- Detects rising edge
pulse:falling()  -- Detects falling edge
```

## Important Notes

1. **scanValue**: The library uses a global `scanValue` that stores intermediate results between function calls, just like the original Arduino library.

2. **State Variables**: Timers and similar stateful functions require table references (e.g., `{value = 0}`) to maintain state between calls.

3. **Bit Operations**: The library uses `bit32` if available, but falls back to arithmetic operations for compatibility with different Lua versions.

4. **Hardware Interface**: You must implement the HAL functions for your specific platform (microcontroller, simulator, etc.).

## License

GNU General Public License v3.0

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

## Differences from Arduino Version

- Hardware abstraction layer required
- No serial monitor functionality (can be added if needed)
- State variables use Lua tables instead of C++ references
- Bit operations use `bit32` library or arithmetic fallbacks
- Pin definitions are symbolic (strings/numbers) rather than hardware registers
