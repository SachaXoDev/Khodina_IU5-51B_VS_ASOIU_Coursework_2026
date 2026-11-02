// ============================================================================
// KOCTA-16 Assembly: Grade 3 Task 16 (Binary Search)
// Description: Search for TARGET in a sorted 16-element array in RAM.
// Memory map:
//   RAM[0x00] : Target search value (input)
//   RAM[0x01] : Result index (output: 0..15 or 0xFFFF if not found)
//   RAM[0x02] : Array length (16)
//   RAM[0x10..0x1F] : 16 sorted elements
// ============================================================================

    // 1. Initialization
    LOAD R1, [R0 + 0]       // R1 = TARGET value from RAM[0x00]
    LDI  R2, 0              // R2 = LOW index = 0
    LDI  R3, 15             // R3 = HIGH index = 15
    LDI  R5, 16             // R5 = Array Base Address = 0x10 (16)
    LDI  R8, 1              // R8 = Constant 1 for increment/decrement

SEARCH_LOOP:
    // Check loop termination condition: if (HIGH < LOW) goto NOT_FOUND
    CMP  R3, R2             // Compare HIGH (R3) with LOW (R2)
    BLT  NOT_FOUND          // If HIGH < LOW, element is absent

    // Compute MID = (LOW + HIGH) >> 1
    ADD  R4, R2, R3         // R4 = LOW + HIGH
    SHR  R4, R4, 1          // R4 = MID = (LOW + HIGH) / 2

    // Calculate memory address: R6 = ARRAY_BASE + MID
    ADD  R6, R5, R4         // R6 = 0x10 + MID

    // Fetch array element: R7 = RAM[R6]
    LOAD R7, [R6 + 0]       // R7 = A[MID]

    // Compare A[MID] with TARGET
    CMP  R7, R1             // Compare A[MID] (R7) with TARGET (R1)
    BEQ  FOUND              // If A[MID] == TARGET, jump to FOUND
    BLT  SEARCH_RIGHT       // If A[MID] < TARGET, search in right half

SEARCH_LEFT:
    // TARGET < A[MID] -> HIGH = MID - 1
    SUB  R3, R4, R8         // HIGH = MID - 1
    JMP  SEARCH_LOOP

SEARCH_RIGHT:
    // TARGET > A[MID] -> LOW = MID + 1
    ADD  R2, R4, R8         // LOW = MID + 1
    JMP  SEARCH_LOOP

FOUND:
    // Write found index to RAM[0x01]
    STORE R4, [R0 + 1]      // RAM[0x01] = MID (index 0..15)
    HALT                    // Stop CPU execution

NOT_FOUND:
    // Write 0xFFFF (-1) to RAM[0x01]
    LDI  R9, 255            // Low byte = 0xFF
    LDH  R9, 255            // High byte = 0xFF -> R9 = 0xFFFF
    STORE R9, [R0 + 1]      // RAM[0x01] = 0xFFFF
    HALT                    // Stop CPU execution
