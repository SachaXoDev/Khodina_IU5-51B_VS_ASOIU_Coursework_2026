// ============================================================================
// KOCTA-16 Assembly: Grade 5 Task 18 (Sokoban Game with PUSH_LOGIC)
// Description: Classic Sokoban puzzle with PUSH_LOGIC hardware acceleration
// Grid: 10 columns x 10 rows (100 tiles in RAM 0x10 - 0x73) with interior walls
// MMIO:
//   0xFF00 : UART Terminal Output
//   0xFF01 : Keyboard Input (ASCII: 'w', 's', 'a', 'd', 'q')
//   0xFF02 : Keyboard Status (bit 0 = key_available)
//   0xFF16 : Move Counter  (base 0xFF00 + 22)
//   0xFF17 : Game Status   (base 0xFF00 + 23, 0 = playing, 1 = victory)
// ============================================================================

START:
    // Constants
    LDI R15, 1              // Constant 1
    LDI R14, 0              // Constant 0

    // Setup MMIO base pointer (R11 = 0xFF00)
    LDI R11, 0
    LDH R11, 255            // R11 = 0xFF00

RESET_GAME:
    // Initialize Game Variables in RAM
    // RAM[0x00] = player position (offset in map: 12 = Row 1, Col 2)
    // RAM[0x01] = move count (0)
    // RAM[0x02] = win status (0)
    LDI R1, 12
    STORE R1, [R0 + 0]      // RAM[0] = 12 (Player Pos)
    STORE R0, [R0 + 1]      // RAM[1] = 0 (Moves)
    STORE R0, [R0 + 2]      // RAM[2] = 0 (Win)

    LDI R3, 22
    ADD R3, R11, R3
    STORE R0, [R3 + 0]      // MMIO[0xFF16] = 0 (Moves)

    LDI R3, 23
    ADD R3, R11, R3
    STORE R0, [R3 + 0]      // MMIO[0xFF17] = 0 (Status)

    // Load Initial Map into RAM (Addresses 0x10 - 0x73)
    CALL INIT_MAP

    // Render Initial Map to UART Terminal
    CALL RENDER_MAP

WAIT_KEY:
    // Poll keyboard status at MMIO[0xFF02]
    LOAD R1, [R11 + 2]      // R1 = MMIO[0xFF02] (key_available)
    CMP R1, R0
    BEQ WAIT_KEY

    // Read key code from MMIO[0xFF01]
    LOAD R2, [R11 + 1]      // R2 = ASCII key
    STORE R0, [R11 + 1]     // Acknowledge key strobe

    // Check quit key 'q' (113) or 'Q' (81)
    LDI R3, 113             // 'q'
    CMP R2, R3
    BEQ DO_QUIT
    LDI R3, 81              // 'Q'
    CMP R2, R3
    BEQ DO_QUIT

    // Check 'w' / 'W' (Up: offset = -10)
    LDI R3, 119             // 'w'
    CMP R2, R3
    BEQ MOVE_UP
    LDI R3, 87              // 'W'
    CMP R2, R3
    BEQ MOVE_UP

    // Check 's' / 'S' (Down: offset = +10)
    LDI R3, 115             // 's'
    CMP R2, R3
    BEQ MOVE_DOWN
    LDI R3, 83              // 'S'
    CMP R2, R3
    BEQ MOVE_DOWN

    // Check 'a' / 'A' (Left: offset = -1)
    LDI R3, 97              // 'a'
    CMP R2, R3
    BEQ MOVE_LEFT
    LDI R3, 65              // 'A'
    CMP R2, R3
    BEQ MOVE_LEFT

    // Check 'd' / 'D' (Right: offset = +1)
    LDI R3, 100             // 'd'
    CMP R2, R3
    BEQ MOVE_RIGHT
    LDI R3, 68              // 'D'
    CMP R2, R3
    BEQ MOVE_RIGHT

    // Unknown key: ignore
    JMP WAIT_KEY

MOVE_UP:
    LDI R12, 10
    SUB R12, R0, R12        // R12 = -10
    JMP PROCESS_MOVE

MOVE_DOWN:
    LDI R12, 10             // R12 = +10
    JMP PROCESS_MOVE

MOVE_LEFT:
    LDI R12, 1
    SUB R12, R0, R12        // R12 = -1
    JMP PROCESS_MOVE

MOVE_RIGHT:
    LDI R12, 1              // R12 = +1
    JMP PROCESS_MOVE

PROCESS_MOVE:
    // R12 = move offset (-10, +10, -1, +1)
    LOAD R1, [R0 + 0]       // R1 = current player position
    ADD R2, R1, R12         // R2 = target position (c1)
    ADD R3, R2, R12         // R3 = beyond position (c2)

    // Load tiles from RAM: RAM base for map is 0x10 (16)
    LDI R13, 16             // Map RAM base = 0x10
    ADD R4, R13, R2         // Address of c1
    LOAD R7, [R4 + 0]       // R7 = tile at c1 (target)

    ADD R5, R13, R3         // Address of c2
    LOAD R8, [R5 + 0]       // R8 = tile at c2 (beyond)

    // ========================================================================
    // HARDWARE ACCELERATION: PUSH_LOGIC
    // R6 = PUSH_LOGIC(tile_target, tile_beyond)
    // Bits [1:0]: 0=Blocked, 1=Walk, 2=Push
    // Bits [15:8]: new_c2 tile code
    // ========================================================================
    PUSH_LOGIC R6, R7, R8

    // Extract status code: R10 = R6 & 3
    LDI R10, 3
    AND R10, R6, R10

    // If R10 == 0 -> Move blocked!
    CMP R10, R0
    BEQ WAIT_KEY

    // Update Player's old cell (at R1)
    ADD R4, R13, R1         // Address of old player pos
    LOAD R9, [R4 + 0]       // Old tile
    LDI R10, 43             // '+' (Player on Goal)
    CMP R9, R10
    BEQ RESTORE_GOAL
    LDI R9, 32              // ' ' (Floor)
    STORE R9, [R4 + 0]
    JMP APPLY_NEW_CELL

RESTORE_GOAL:
    LDI R9, 46              // '.' (Goal)
    STORE R9, [R4 + 0]

APPLY_NEW_CELL:
    // Check if move was Walk (1) or Push (2)
    LDI R10, 3
    AND R10, R6, R10
    LDI R9, 2
    CMP R10, R9
    BNE DO_WALK_ONLY

    // Push Move (Status == 2):
    // Write new box tile at beyond cell (R3):
    // R6[15:8] contains the updated tile for beyond cell
    SHR R9, R6, 8           // R9 = new_c2 tile
    ADD R5, R13, R3         // Address of beyond cell
    STORE R9, [R5 + 0]

DO_WALK_ONLY:
    // Write new player tile at target cell (R2):
    // If target had goal ('.' or '*') -> new is '+' (43), else '@' (64)
    ADD R4, R13, R2         // Address of target cell
    LDI R10, 46             // '.'
    CMP R7, R10
    BEQ SET_PLAYER_GOAL
    LDI R10, 42             // '*' (Box on Goal)
    CMP R7, R10
    BEQ SET_PLAYER_GOAL
    LDI R9, 64              // '@'
    STORE R9, [R4 + 0]
    JMP FINISH_MOVE

SET_PLAYER_GOAL:
    LDI R9, 43              // '+'
    STORE R9, [R4 + 0]

FINISH_MOVE:
    // Update player position in RAM
    STORE R2, [R0 + 0]

    // Increment Move Counter
    LOAD R9, [R0 + 1]
    ADD R9, R9, R15
    STORE R9, [R0 + 1]

    LDI R3, 22
    ADD R3, R11, R3
    STORE R9, [R3 + 0]      // MMIO[0xFF16] = Moves

    // Check Victory Condition:
    // Goal is at index 37 (RAM[16 + 37] = RAM[53])
    LDI R4, 53              // 16 + 37 = 53
    LOAD R7, [R4 + 0]       // Tile at Goal
    LDI R10, 42             // '*' (Box on Goal)
    CMP R7, R10
    BNE NOT_YET_WON

    // VICTORY!
    STORE R15, [R0 + 2]     // RAM[2] = 1 (Won)
    LDI R3, 23
    ADD R3, R11, R3
    STORE R15, [R3 + 0]     // MMIO[0xFF17] = 1 (Won)

NOT_YET_WON:
    CALL RENDER_MAP
    JMP WAIT_KEY

DO_QUIT:
    HALT

// ============================================================================
// SUBROUTINE: INIT_MAP
// Initializes 10x10 Sokoban Grid in RAM at 0x10 - 0x73 with Interior Walls
// ============================================================================
INIT_MAP:
    LDI R1, 35              // '#' = 35
    LDI R2, 32              // ' ' = 32
    LDI R3, 64              // '@' = 64
    LDI R4, 36              // '$' = 36
    LDI R5, 46              // '.' = 46

    // Fill all 100 tiles with spaces first
    LDI R6, 16
    LDI R7, 100
CLEAR_SPACES:
    STORE R2, [R6 + 0]
    ADD R6, R6, R15
    SUB R7, R7, R15
    BNE CLEAR_SPACES

    // Write non-space tiles by 16-word chunks:
    // Chunk 0: RAM[16..31]
    LDI R6, 16
    STORE R1, [R6 + 0]     // Tile 0 (#)
    STORE R1, [R6 + 1]     // Tile 1 (#)
    STORE R1, [R6 + 2]     // Tile 2 (#)
    STORE R1, [R6 + 3]     // Tile 3 (#)
    STORE R1, [R6 + 4]     // Tile 4 (#)
    STORE R1, [R6 + 5]     // Tile 5 (#)
    STORE R1, [R6 + 6]     // Tile 6 (#)
    STORE R1, [R6 + 7]     // Tile 7 (#)
    STORE R1, [R6 + 8]     // Tile 8 (#)
    STORE R1, [R6 + 9]     // Tile 9 (#)
    STORE R1, [R6 + 10]    // Tile 10 (#)
    STORE R3, [R6 + 12]    // Tile 12 (@) - Player Start

    // Chunk 1: RAM[32..47]
    LDI R6, 32
    STORE R1, [R6 + 3]     // Tile 19 (#)
    STORE R1, [R6 + 4]     // Tile 20 (#)
    STORE R1, [R6 + 7]     // Tile 23 (#) - Pillar 1
    STORE R1, [R6 + 8]     // Tile 24 (#)
    STORE R1, [R6 + 13]    // Tile 29 (#)
    STORE R1, [R6 + 14]    // Tile 30 (#)

    // Chunk 2: RAM[48..63]
    LDI R6, 48
    STORE R1, [R6 + 1]     // Tile 33 (#) - Pillar 1
    STORE R1, [R6 + 2]     // Tile 34 (#)
    STORE R5, [R6 + 5]     // Tile 37 (.) - Goal
    STORE R1, [R6 + 7]     // Tile 39 (#)
    STORE R1, [R6 + 8]     // Tile 40 (#)

    // Chunk 3: RAM[64..79]
    LDI R6, 64
    STORE R1, [R6 + 1]     // Tile 49 (#)
    STORE R1, [R6 + 2]     // Tile 50 (#)
    STORE R4, [R6 + 6]     // Tile 54 ($) - Box Start
    STORE R1, [R6 + 11]    // Tile 59 (#)
    STORE R1, [R6 + 12]    // Tile 60 (#)
    STORE R1, [R6 + 15]    // Tile 63 (#) - Pillar 2

    // Chunk 4: RAM[80..95]
    LDI R6, 80
    STORE R1, [R6 + 0]     // Tile 64 (#)
    STORE R1, [R6 + 5]     // Tile 69 (#)
    STORE R1, [R6 + 6]     // Tile 70 (#)
    STORE R1, [R6 + 9]     // Tile 73 (#) - Pillar 2
    STORE R1, [R6 + 10]    // Tile 74 (#)
    STORE R1, [R6 + 15]    // Tile 79 (#)

    // Chunk 5: RAM[96..111]
    LDI R6, 96
    STORE R1, [R6 + 0]     // Tile 80 (#)
    STORE R1, [R6 + 9]     // Tile 89 (#)
    STORE R1, [R6 + 10]    // Tile 90 (#)
    STORE R1, [R6 + 11]    // Tile 91 (#)
    STORE R1, [R6 + 12]    // Tile 92 (#)
    STORE R1, [R6 + 13]    // Tile 93 (#)
    STORE R1, [R6 + 14]    // Tile 94 (#)
    STORE R1, [R6 + 15]    // Tile 95 (#)

    // Chunk 6: RAM[112..115]
    LDI R6, 112
    STORE R1, [R6 + 0]     // Tile 96 (#)
    STORE R1, [R6 + 1]     // Tile 97 (#)
    STORE R1, [R6 + 2]     // Tile 98 (#)
    STORE R1, [R6 + 3]     // Tile 99 (#)

    RET

// ============================================================================
// SUBROUTINE: RENDER_MAP
// Outputs 10x10 grid to UART at 0xFF00 followed by newline
// ============================================================================
RENDER_MAP:
    LDI R7, 16              // RAM start address = 16
    LDI R8, 100             // 100 total tiles
    LDI R9, 10              // '\n' ASCII = 10
    LDI R10, 10             // Column counter = 10 per row

PRINT_LOOP:
    LOAD R1, [R7 + 0]       // Read tile ASCII
    STORE R1, [R11 + 0]     // Write to UART MMIO[0xFF00]
    ADD R7, R7, R15         // Next tile address
    SUB R8, R8, R15         // Decrement remaining tiles
    BEQ PRINT_DONE

    // Decrement column counter
    SUB R10, R10, R15
    BNE PRINT_LOOP

    // End of row: output newline and reset column counter
    STORE R9, [R11 + 0]
    LDI R10, 10
    JMP PRINT_LOOP

PRINT_DONE:
    STORE R9, [R11 + 0]     // Trailing newline
    RET
