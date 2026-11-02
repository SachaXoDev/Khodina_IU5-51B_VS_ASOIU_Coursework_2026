// ============================================================================
// File: alu.v
// Module: alu
// Description: 16-bit Arithmetic Logic Unit with Hardware Acceleration
// Supports CROSS_XOR (Lights Out) and PUSH_LOGIC (Sokoban)
// ============================================================================
`timescale 1ns / 1ps

module alu (
    input  wire [3:0]  alu_op,      // ALU Operation Code
    input  wire [15:0] a,           // Operand A (Rs1)
    input  wire [15:0] b,           // Operand B (Rs2 / Shift / Control)
    output reg  [15:0] result,      // ALU Result (Rd)
    output wire        flag_z,      // Zero Flag
    output wire        flag_n       // Negative Flag (Sign bit)
);

    // ALU Operation Constants
    localparam ALU_NOP        = 4'h0;
    localparam ALU_ADD        = 4'h1;
    localparam ALU_SUB        = 4'h2;
    localparam ALU_AND        = 4'h3;
    localparam ALU_OR         = 4'h4;
    localparam ALU_XOR        = 4'h5;
    localparam ALU_SLT        = 4'h6;
    localparam ALU_SHL        = 4'hC;
    localparam ALU_SHR        = 4'hD;
    localparam ALU_PUSH_LOGIC = 4'hE;
    localparam ALU_CROSS_XOR  = 4'hF;

    // Cross XOR hardware unit instance (Task 16: Lights Out)
    wire [15:0] cross_xor_res;
    cross_xor u_cross_xor (
        .row_in(a),
        .control_in(b),
        .row_out(cross_xor_res)
    );

    // Push Logic hardware acceleration unit instance (Task 18: Sokoban)
    wire [15:0] push_logic_res;
    push_logic u_push_logic (
        .tile_target(a[7:0]),
        .tile_beyond(b[7:0]),
        .move_status(),
        .new_c1(),
        .new_c2(),
        .res(push_logic_res)
    );

    always @(*) begin
        case (alu_op)
            ALU_ADD:        result = a + b;
            ALU_SUB:        result = a - b;
            ALU_AND:        result = a & b;
            ALU_OR:         result = a | b;
            ALU_XOR:        result = a ^ b;
            ALU_SLT:        result = ($signed(a) < $signed(b)) ? 16'h0001 : 16'h0000;
            ALU_SHL:        result = a << b[3:0];
            ALU_SHR:        result = a >> b[3:0];
            ALU_PUSH_LOGIC: result = push_logic_res;
            ALU_CROSS_XOR:  result = cross_xor_res;
            default:        result = a;
        endcase
    end

    assign flag_z = (result == 16'h0000);
    assign flag_n = result[15];

endmodule
