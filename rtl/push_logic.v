// ============================================================================
// File: push_logic.v
// Module: push_logic
// Description: Dedicated Hardware Acceleration Unit for Sokoban (Task 18)
// Course: Computer Systems of ASOIU (VS ASOIU 2026)
// Author: IU5 Student (Khodina A. P., Group IU5-51B, Variant 16)
// ============================================================================
//
// Tile definitions (ASCII):
//   ' ' (0x20) = Floor (Empty)
//   '#' (0x23) = Wall
//   '$' (0x24) = Box
//   '.' (0x2E) = Goal / Target
//   '*' (0x2A) = Box on Goal
//   '@' (0x40) = Player
//   '+' (0x2B) = Player on Goal
//
// Inputs:
//   tile_target (c1)  : 8-bit tile at destination position (player + dir)
//   tile_beyond (c2)  : 8-bit tile at position beyond box (player + 2*dir)
//
// Outputs:
//   move_status [1:0] : 2'b00 = BLOCKED (Cannot move)
//                       2'b01 = MOVE_ONLY (Walk into empty space / goal)
//                       2'b10 = PUSH_MOVE (Push box into empty space / goal)
//   new_c1 [7:0]      : Resulting tile at target position
//   new_c2 [7:0]      : Resulting tile at beyond position
//   res [15:0]        : Packed result: {new_c2[7:0], 6'b0, move_status[1:0]}
//
// In 1 single clock cycle, this unit evaluates all collision matrices,
// boundary conditions and target state transitions without nested branches!
// ============================================================================

`timescale 1ns / 1ps

module push_logic (
    input  wire [7:0]  tile_target, // c1: cell player wants to move to
    input  wire [7:0]  tile_beyond, // c2: cell behind c1 in move direction
    output reg  [1:0]  move_status, // 00=Blocked, 01=Walk, 10=Push
    output reg  [7:0]  new_c1,      // New tile at c1 (player position)
    output reg  [7:0]  new_c2,      // New tile at c2 (box position if pushed)
    output wire [15:0] res          // Packed result for Rd register
);

    localparam T_FLOOR       = 8'h20; // ' '
    localparam T_WALL        = 8'h23; // '#'
    localparam T_BOX         = 8'h24; // '$'
    localparam T_GOAL        = 8'h2E; // '.'
    localparam T_BOX_ON_GOAL = 8'h2A; // '*'
    localparam T_PLAYER      = 8'h40; // '@'
    localparam T_PLAYER_GOAL = 8'h2B; // '+'

    wire c1_is_walkable = (tile_target == T_FLOOR) || (tile_target == T_GOAL);
    wire c1_is_box      = (tile_target == T_BOX)   || (tile_target == T_BOX_ON_GOAL);
    wire c2_is_free     = (tile_beyond == T_FLOOR) || (tile_beyond == T_GOAL);

    always @(*) begin
        if (c1_is_walkable) begin
            // Simple step forward into floor or goal
            move_status = 2'b01;
            new_c1 = (tile_target == T_GOAL) ? T_PLAYER_GOAL : T_PLAYER;
            new_c2 = tile_beyond;
        end else if (c1_is_box && c2_is_free) begin
            // Valid box push!
            move_status = 2'b10;
            new_c1 = (tile_target == T_BOX_ON_GOAL) ? T_PLAYER_GOAL : T_PLAYER;
            new_c2 = (tile_beyond == T_GOAL) ? T_BOX_ON_GOAL : T_BOX;
        end else begin
            // Blocked by wall or unmovable box
            move_status = 2'b00;
            new_c1 = tile_target;
            new_c2 = tile_beyond;
        end
    end

    // Result format:
    // Bits [1:0]   : move_status (0=Blocked, 1=Walk, 2=Push)
    // Bits [7:2]   : Reserved (zero)
    // Bits [15:8]  : new_c2 tile code (allows 1-instruction box tile placement)
    assign res = {new_c2, 6'b000000, move_status};

endmodule
