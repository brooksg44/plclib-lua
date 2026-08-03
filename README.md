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

Put `plcLib.lua` somewhere on your Lua path and require it:

```lua
package.path = package.path .. ";./?.lua;./?/?.lua"
local plcLib = require("plcLib")
```

If you keep the library in a directory of its own, `init.lua` lets you require
the directory by name instead:

```lua
local plcLib = require("plcLib.plcLib")
```

## Pins and Values

Every input-side function takes **either a pin to read or a value to use directly**, and tells them apart by Lua type:

| Argument | Meaning | Example |
| --- | --- | --- |
| **string** | A pin identifier — the function reads it through the HAL | `plcLib.input(plcLib.X0)` |
| **number** | A plain value — used as-is, no hardware access | `plcLib.input(memoryBit)` |

```lua
plcLib.input(plcLib.X0)   -- string "A0" -> digitalRead("A0")
plcLib.input(1)           -- number      -> scanValue = 1
```

This mirrors how the Arduino original works. There, the distinction is made by C++ overloading — `in(int)` calls `digitalRead()` while `in(unsigned int)` takes the argument as a value, and the compiler picks between them. Lua has only one number type, so the pin case is carried by strings instead.

**Every pin constant is therefore a string**, including the output pins:

```lua
plcLib.X0 = "A0"    plcLib.Y0 = "3"     plcLib.DIRA  = "12"
plcLib.X1 = "A1"    plcLib.Y1 = "5"     plcLib.PWMA  = "3"
```

The value form exists mainly to read back an internal memory bit you wrote with `plcLib.output(bit)`, though it is equally useful for feeding constants into a rung:

```lua
local motorRun = {value = 0}

plcLib.input(plcLib.X0)
plcLib.output(motorRun)        -- write to the memory bit

plcLib.input(motorRun.value)   -- number -> read it back
plcLib.andBit(plcLib.X1)       -- string -> read pin A1
plcLib.output(plcLib.Y0)
```

> **Watch out:** passing a bare number where you meant a pin silently loads that number as a value instead of reading hardware. `plcLib.input(3)` sets `scanValue` to `3`; it does not read pin 3. Always use the pin constants, or quote the pin number.

## Hardware Abstraction Layer

Since Lua doesn't have direct hardware access like Arduino, you need to provide a Hardware Abstraction Layer (HAL) for your specific platform.

Pin identifiers reach the HAL exactly as written — as **strings** such as `"A0"` or `"3"`. If your platform's API wants numbers, convert at this boundary:

```lua
digitalWrite = function(pin, value)
    myBoard.write(tonumber(pin) or pin, value)
end
```

```lua
local plcLib = require("plcLib")

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
local plcLib = require("plcLib")

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

Throughout, `source` means a string pin identifier **or** a number used directly as a value — see [Pins and Values](#pins-and-values). `target` means a string pin identifier or a `{value = 0}` table to write into.

### Input/Output Functions

- `plcLib.input(source)` - Read digital input
- `plcLib.inputNot(source)` - Read inverted digital input
- `plcLib.inputAnalog(source)` - Read analog input (0-1023)
- `plcLib.output(target)` - Write digital output
- `plcLib.outputNot(target)` - Write inverted output
- `plcLib.outputPWM(target)` - Write PWM output (`scanValue / 4`)

`plcLib.i` and `plcLib.o` are aliases for `input` and `output`.

### Logic Functions

Each combines `scanValue` with the source and stores the result back in `scanValue`.

- `plcLib.andBit(source)` - AND with scanValue
- `plcLib.andNotBit(source)` - AND NOT with scanValue
- `plcLib.orBit(source)` - OR with scanValue
- `plcLib.orNotBit(source)` - OR NOT with scanValue
- `plcLib.xorBit(source)` - XOR with scanValue

These are **bitwise** operations, matching the C original (`scanValue & input`, `| `, `^`, and `& ~input`). For ordinary ladder logic, where everything is 0 or 1, bitwise and boolean logic agree and the distinction never surfaces. It matters only when `scanValue` holds a multi-bit value — see the note on analog values below.

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

3. **Bit Operations**: The library uses `bit32` if available, but falls back to arithmetic operations for compatibility with different Lua versions. The Lua 5.3+ bitwise operators (`&`, `|`, `~`) are avoided on purpose — they are a *parse* error on Lua 5.1 and 5.2, so using them would stop the library loading there at all.

4. **Hardware Interface**: You must implement the HAL functions for your specific platform (microcontroller, simulator, etc.).

5. **Normalise analog values before mixing them with logic**: `inputAnalog` leaves a 0-1023 value in `scanValue`. Pass it through `compareGT` or `compareLT` to reduce it to 0 or 1 before feeding it to the logic functions or to `output`:

   ```lua
   plcLib.inputAnalog(plcLib.X0)   -- scanValue = 0..1023
   plcLib.compareGT(500)           -- scanValue = 1 or 0
   plcLib.andBit(plcLib.X1)        -- now safe to combine
   plcLib.output(plcLib.Y0)
   ```

   Skipping the comparison does not raise an error, it just gives results that follow the C original's bit-level behaviour rather than the truth table you probably intended. With `scanValue = 512`, `andBit(1)` yields `0` (no bits in common), and `output` treats anything other than exactly `1` as off. This is upstream behaviour, reproduced here deliberately.

## Tests

```
lua test/run.lua
```

Individual suites run on their own as well, e.g. `lua test/test_bitwise.lua`. Both exit non-zero on failure.

- `test_overloads` - the string/number pin-vs-value dispatch across all eight dispatching functions
- `test_bitwise` - the logic functions against the native Lua 5.3+ bitwise operators as an oracle, over every input pair in 0..255
- `test_upstream_quirks` - the places this port deliberately keeps upstream's odd behaviour, so "fixing" them fails the tests
- `test_readme` - the code snippets in this file, so the docs cannot drift from the library

## License

GNU General Public License v3.0

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

## Differences from Arduino Version

- Hardware abstraction layer required
- No serial monitor functionality (can be added if needed)
- State variables use Lua tables (`{value = 0}`) instead of C++ references
- Bit operations use `bit32` library or arithmetic fallbacks
- Pin definitions are symbolic strings rather than hardware registers
- C++ overloading is emulated with Lua types: a **string** argument selects the pin overload (`in(int)`, reads hardware), a **number** selects the value overload (`in(unsigned int)`)

Behaviour otherwise follows the original, including where the original is quirky. `orNotBit`, `output` and `outputNot` test `scanValue == 1` rather than "is non-zero", which is why an un-normalised analog value reads as off in those three functions but not in the others. That is how the C source behaves, and the port reproduces it rather than silently correcting it.
