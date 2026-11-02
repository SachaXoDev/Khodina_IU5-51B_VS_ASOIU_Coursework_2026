// ============================================================================
// File: register_file.v
// Module: register_file
// Description: 16x16-bit Dual-Port Read, Single-Port Write Register File
//              R0 is hardwired to 0 (reads 0x0000, writes ignored).
// ============================================================================
`timescale 1ns / 1ps

module register_file (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,
    input  wire [3:0]  read_addr1,
    input  wire [3:0]  read_addr2,
    input  wire [3:0]  write_addr,
    input  wire [15:0] write_data,
    output wire [15:0] read_data1,
    output wire [15:0] read_data2
);

    reg [15:0] registers [15:0];
    integer i;

    // Synchronous write block
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                registers[i] <= 16'h0000;
            end
        end else if (we && (write_addr != 4'h0)) begin
            registers[write_addr] <= write_data;
        end
    end

    // Asynchronous read block with Hardwired Zero on R0
    assign read_data1 = (read_addr1 == 4'h0) ? 16'h0000 : registers[read_addr1];
    assign read_data2 = (read_addr2 == 4'h0) ? 16'h0000 : registers[read_addr2];

endmodule
