// ============================================================================
// KOCTA-16 Assembly: Grade 4 Task 23 (Washing Machine Controller)
// Description: FSM Timer Controller for Washing Machine with MMIO LED Steps:
//   Step 1: Water Fill    (LED 0x0001)
//   Step 2: Drum Rotation (LED 0x0002)
//   Step 3: Water Drain   (LED 0x0004)
//   Step 4: Spin Drying   (LED 0x0008)
//   Step 5: Done / Standby(LED 0x0010)
// Countdown timer displayed at MMIO Display (0xFF20).
// ============================================================================

START:
    // Setup MMIO pointers
    LDI R11, 16             // Low byte of 0xFF10 (16 = 0x10)
    LDH R11, 255            // High byte = 0xFF -> R11 = 0xFF10 (LED output)
    LDI R12, 32             // Low byte of 0xFF20
    LDH R12, 255            // R12 = 0xFF20 (Countdown Display)
    LDI R15, 1              // Constant 1 for decrement

    // ------------------------------------------------------------------------
    // STAGE 1: WATER FILL (LED = 0x0001)
    // ------------------------------------------------------------------------
STAGE1_FILL:
    LDI R1, 1               // Stage 1 LED bit (0x0001)
    STORE R1, [R11 + 0]     // MMIO[0xFF10] = 0x0001

    // Timer = 3
    LDI R2, 3
    STORE R2, [R12 + 0]     // Display = 3
    CALL DELAY_STEP
    LDI R2, 2
    STORE R2, [R12 + 0]     // Display = 2
    CALL DELAY_STEP
    LDI R2, 1
    STORE R2, [R12 + 0]     // Display = 1
    CALL DELAY_STEP

    // ------------------------------------------------------------------------
    // STAGE 2: DRUM WASH & ROTATION (LED = 0x0002)
    // ------------------------------------------------------------------------
STAGE2_WASH:
    LDI R1, 2               // Stage 2 LED bit (0x0002)
    STORE R1, [R11 + 0]     // MMIO[0xFF10] = 0x0002

    // Timer = 4
    LDI R2, 4
    STORE R2, [R12 + 0]     // Display = 4
    CALL DELAY_STEP
    LDI R2, 3
    STORE R2, [R12 + 0]     // Display = 3
    CALL DELAY_STEP
    LDI R2, 2
    STORE R2, [R12 + 0]     // Display = 2
    CALL DELAY_STEP
    LDI R2, 1
    STORE R2, [R12 + 0]     // Display = 1
    CALL DELAY_STEP

    // ------------------------------------------------------------------------
    // STAGE 3: WATER DRAIN (LED = 0x0004)
    // ------------------------------------------------------------------------
STAGE3_DRAIN:
    LDI R1, 4               // Stage 3 LED bit (0x0004)
    STORE R1, [R11 + 0]     // MMIO[0xFF10] = 0x0004

    // Timer = 2
    LDI R2, 2
    STORE R2, [R12 + 0]     // Display = 2
    CALL DELAY_STEP
    LDI R2, 1
    STORE R2, [R12 + 0]     // Display = 1
    CALL DELAY_STEP

    // ------------------------------------------------------------------------
    // STAGE 4: SPIN DRYING (LED = 0x0008)
    // ------------------------------------------------------------------------
STAGE4_SPIN:
    LDI R1, 8               // Stage 4 LED bit (0x0008)
    STORE R1, [R11 + 0]     // MMIO[0xFF10] = 0x0008

    // Timer = 3
    LDI R2, 3
    STORE R2, [R12 + 0]     // Display = 3
    CALL DELAY_STEP
    LDI R2, 2
    STORE R2, [R12 + 0]     // Display = 2
    CALL DELAY_STEP
    LDI R2, 1
    STORE R2, [R12 + 0]     // Display = 1
    CALL DELAY_STEP

    // ------------------------------------------------------------------------
    // STAGE 5: CYCLE COMPLETE (LED = 0x0010, Display = 0)
    // ------------------------------------------------------------------------
STAGE5_DONE:
    LDI R1, 16              // Stage 5 LED bit (0x0010)
    STORE R1, [R11 + 0]     // MMIO[0xFF10] = 0x0010
    LDI R2, 0
    STORE R2, [R12 + 0]     // Display = 0
    HALT

    // ------------------------------------------------------------------------
    // SUBROUTINE: DELAY_STEP
    // Performs short programmable delay loop
    // ------------------------------------------------------------------------
DELAY_STEP:
    LDI R3, 5               // Delay count = 5 iterations
DELAY_LOOP:
    SUB R3, R3, R15         // R3 = R3 - 1
    BNE DELAY_LOOP
    RET
