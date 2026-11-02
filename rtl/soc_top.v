// ============================================================================
// File: soc_top.v
// Module: soc_top
// Description: Top-Level System-on-Chip (SoC) integrating KOCTA-16 CPU,
//              Harvard Memory (ROM + RAM), and MMIO Peripherals.
// ============================================================================
`timescale 1ns / 1ps

module soc_top #(
    parameter ROM_INIT_FILE = "",
    parameter RAM_INIT_FILE = ""
)(
    input  wire        clk,
    input  wire        rst,

    // External Interactive Interface (Keyboard / Gamepad)
    input  wire [15:0] ext_key_data,
    input  wire        ext_key_strobe,

    // External Visual Outputs (LED Matrix & Display)
    output wire [24:0] ext_led_matrix,
    output wire [2:0]  ext_cursor_x,
    output wire [2:0]  ext_cursor_y,
    output wire [15:0] ext_moves_count,
    output wire        ext_game_won,
    output wire [15:0] ext_rpn_display,

    // System Status
    output wire        cpu_halted,
    output wire        sim_halt_requested,
    output wire [7:0]  current_pc,
    output wire [15:0] r15_flags
);

    // CPU Bus Signals
    wire [7:0]  cpu_rom_addr;
    wire [15:0] cpu_rom_data;
    wire [15:0] cpu_mem_addr;
    wire [15:0] cpu_mem_wdata;
    wire        cpu_mem_we;
    wire        cpu_mem_re;
    wire [15:0] cpu_mem_rdata;

    // Address Decoders
    wire is_ram_access  = (cpu_mem_addr[15:8] == 8'h00);
    wire is_mmio_access = (cpu_mem_addr[15:8] == 8'hFF);

    wire ram_we = cpu_mem_we & is_ram_access;
    wire ram_re = cpu_mem_re & is_ram_access;
    wire [15:0] ram_rdata;

    wire mmio_we = cpu_mem_we & is_mmio_access;
    wire mmio_re = cpu_mem_re & is_mmio_access;
    wire [15:0] mmio_rdata;

    // Bus Read Multiplexer
    assign cpu_mem_rdata = is_mmio_access ? mmio_rdata : ram_rdata;

    // 1. CPU Core Instance
    cpu_core u_cpu (
        .clk(clk),
        .rst(rst),
        .rom_addr(cpu_rom_addr),
        .rom_data(cpu_rom_data),
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_we(cpu_mem_we),
        .mem_re(cpu_mem_re),
        .mem_rdata(cpu_mem_rdata),
        .halted(cpu_halted),
        .current_pc(current_pc),
        .r15_flags(r15_flags)
    );

    // 2. Memory Subsystem Instance (ROM + RAM)
    memory_top #(
        .ROM_INIT_FILE(ROM_INIT_FILE),
        .RAM_INIT_FILE(RAM_INIT_FILE)
    ) u_memory (
        .clk(clk),
        .rst(rst),
        .rom_addr(cpu_rom_addr),
        .rom_data(cpu_rom_data),
        .ram_addr(cpu_mem_addr[7:0]),
        .ram_wdata(cpu_mem_wdata),
        .ram_we(ram_we),
        .ram_re(ram_re),
        .ram_rdata(ram_rdata)
    );

    // 3. MMIO Peripherals Instance
    mmio u_mmio (
        .clk(clk),
        .rst(rst),
        .bus_addr(cpu_mem_addr),
        .bus_wdata(cpu_mem_wdata),
        .bus_we(mmio_we),
        .bus_re(mmio_re),
        .bus_rdata(mmio_rdata),
        .ext_key_data(ext_key_data),
        .ext_key_strobe(ext_key_strobe),
        .ext_led_matrix(ext_led_matrix),
        .ext_cursor_x(ext_cursor_x),
        .ext_cursor_y(ext_cursor_y),
        .ext_moves_count(ext_moves_count),
        .ext_game_won(ext_game_won),
        .ext_rpn_display(ext_rpn_display),
        .ext_sim_halt(sim_halt_requested)
    );

endmodule
