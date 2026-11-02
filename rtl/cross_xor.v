// ============================================================================
// File: cross_xor.v
// Module: cross_xor
// Description: Dedicated Hardware Acceleration Unit for Lights Out (5x5 Grid)
// Variant: 16 (Grade 5 Hardware Acceleration)
// Author: IU5 Student (Coursework VS ASOIU 2026)
// ============================================================================
`timescale 1ns / 1ps

module cross_xor (
    input  wire [15:0] row_in,       // Bits [4:0]: Current 5-bit row state
    input  wire [15:0] control_in,   // [2:0]: click_x, [5:3]: click_y, [8:6]: current_row
    output reg  [15:0] row_out       // Bits [4:0]: Updated 5-bit row state after cross mask
);

    wire [2:0] click_x     = control_in[2:0];
    wire [2:0] click_y     = control_in[5:3];
    wire [2:0] current_row = control_in[8:6];

    reg [4:0] mask;

    always @(*) begin
        mask = 5'b00000;

        if (current_row == click_y) begin
            // Center row: invert clicked cell and orthogonal horizontal neighbors (left, right)
            if (click_x <= 3'd4) begin
                mask[click_x] = 1'b1;
                if (click_x > 3'd0) begin
                    mask[click_x - 3'd1] = 1'b1;
                end
                if (click_x < 3'd4) begin
                    mask[click_x + 3'd1] = 1'b1;
                end
            end
        end else if ((click_y > 3'd0 && current_row == click_y - 3'd1) ||
                     (click_y < 3'd4 && current_row == click_y + 3'd1)) begin
            // Adjacent row directly above or below: invert only the cell at click_x
            if (click_x <= 3'd4) begin
                mask[click_x] = 1'b1;
            end
        end else begin
            // Non-adjacent row: no change
            mask = 5'b00000;
        end

        row_out = {11'b0, row_in[4:0] ^ mask};
    end

endmodule
