# plcLib Lua - Changelog

## Version 1.4.0-lua (2024-11-14)

### Fixed
- **Counter edge detection**: Fixed the countUp() and countDown() methods to properly detect rising edges. The counter now correctly increments/decrements on each clock pulse transition from 0 to 1.
  - Counter now properly counts up from 0 to preset value
  - upperQ flag correctly set when count reaches preset value
  - Edge detection properly resets when clock signal goes low

- **Shift register operation**: Fixed shiftLeft() method to properly shift bits and maintain 16-bit register size.
  - Added mask to keep register within 16-bit range (0-65535)
  - Edge detection now works correctly for clock pulses
  - Input bits properly shifted into the register

### Example Updates
- Updated counter example to show proper clock signal toggling
- Updated shift register example to demonstrate correct input bit setting and clock pulsing
- Both examples now properly demonstrate rising/falling edge detection

### Test Results
All examples now produce correct output:
- Counter: Counts 1→2→3→4→5, upperQ=1 at 5
- Shift register: Pattern 1,0,1,1 produces values 1→2→5→11 (binary: 0001→0010→0101→1011)
