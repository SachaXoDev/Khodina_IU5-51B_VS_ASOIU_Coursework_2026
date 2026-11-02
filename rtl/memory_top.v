// ============================================================================
// File: memory_top.v
// Module: memory_top
// Description: Harvard Memory Subsystem (Instruction ROM + Data RAM)
// ============================================================================
`timescale 1ns / 1ps

module memory_top #(
    parameter ROM_INIT_FILE = "",
    parameter RAM_INIT_FILE = ""
)(
    input  wire        clk,
    input  wire        rst,

    // Instruction ROM Interface
    input  wire [7:0]  rom_addr,
    output wire [15:0] rom_data,

    // Data RAM Interface
    input  wire [7:0]  ram_addr,
    input  wire [15:0] ram_wdata,
    input  wire        ram_we,
    input  wire        ram_re,
    output wire [15:0] ram_rdata
);

    // 256 words x 16-bit Instruction ROM
    reg [15:0] rom [0:255];

    // 256 words x 16-bit Data RAM
    reg [15:0] ram [0:255];

    integer i;

    // ROM Initialization
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            rom[i] = 16'h0000; // Default NOP
        end
        if (ROM_INIT_FILE != "") begin
            $readmemh(ROM_INIT_FILE, rom);
        end
    end

    // RAM Initialization
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            ram[i] = 16'h0000;
        end
        if (RAM_INIT_FILE != "") begin
            $readmemh(RAM_INIT_FILE, ram);
        end
    end

    // Instruction ROM read (combinational / transparent for FSM fetch)
    assign rom_data = rom[rom_addr];

    // Data RAM synchronous write
    always @(posedge clk) begin
        if (ram_we) begin
            ram[ram_addr] <= ram_wdata;
        end
    end

    // Data RAM read (combinational / registered)
    assign ram_rdata = ram_re ? ram[ram_addr] : 16'h0000;

endmodule
