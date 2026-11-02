// ============================================================================
// File: tb_binary_search.v
// Module: tb_binary_search
// Description: Automated Testbench for Grade 3 Task 16 (Binary Search)
// ============================================================================
`timescale 1ns / 1ps

module tb_binary_search;

    reg clk;
    reg rst;
    reg [15:0] ext_key_data;
    reg ext_key_strobe;

    wire [24:0] ext_led_matrix;
    wire [2:0]  ext_cursor_x;
    wire [2:0]  ext_cursor_y;
    wire [15:0] ext_moves_count;
    wire        ext_game_won;
    wire [15:0] ext_rpn_display;
    wire        cpu_halted;
    wire        sim_halt_requested;
    wire [7:0]  current_pc;
    wire [15:0] r15_flags;

    // Instantiate SoC Top with Binary Search ROM and Data RAM
    soc_top #(
        .ROM_INIT_FILE("firmware/binary_search.hex"),
        .RAM_INIT_FILE("firmware/binary_search_data.hex")
    ) dut (
        .clk(clk),
        .rst(rst),
        .ext_key_data(ext_key_data),
        .ext_key_strobe(ext_key_strobe),
        .ext_led_matrix(ext_led_matrix),
        .ext_cursor_x(ext_cursor_x),
        .ext_cursor_y(ext_cursor_y),
        .ext_moves_count(ext_moves_count),
        .ext_game_won(ext_game_won),
        .ext_rpn_display(ext_rpn_display),
        .cpu_halted(cpu_halted),
        .sim_halt_requested(sim_halt_requested),
        .current_pc(current_pc),
        .r15_flags(r15_flags)
    );

    // Clock generation: 100 MHz (10 ns period)
    always #5 clk = ~clk;

    integer cycles;
    wire [15:0] ram_res = dut.u_memory.ram[1];
    wire [15:0] target  = dut.u_memory.ram[0];

    initial begin
        $dumpfile("sim/waveform_binary_search.vcd");
        $dumpvars(0, tb_binary_search);

        clk = 0;
        rst = 1;
        ext_key_data = 0;
        ext_key_strobe = 0;
        cycles = 0;

        $display("================================================================");
        $display("=== STARTING SIMULATION: GRADE 3 BINARY SEARCH (TASK 16)     ===");
        $display("================================================================");

        #20 rst = 0;
        $display("[T=%0t] Reset released. Target to find = %0d (0x%04X)", $time, target, target);

        // Run until CPU halts or timeout
        while (!cpu_halted && cycles < 1000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        #20;
        $display("[T=%0t] CPU Halted after %0d clock cycles.", $time, cycles);
        $display("----------------------------------------------------------------");
        $display("Verification Results:");
        $display("  Target value in RAM[0x00] : %0d (0x%04X)", target, target);
        $display("  Search Result in RAM[0x01]: %0d (0x%04X)", ram_res, ram_res);
        $display("  Expected Index            : 6");

        if (ram_res === 16'd6) begin
            $display(">>> TEST PASSED: Found target %0d at correct index %0d!", target, ram_res);
        end else begin
            $display(">>> TEST FAILED: Expected index 6, got %0d (0x%04X)", ram_res, ram_res);
        end
        $display("================================================================");

        $finish;
    end

endmodule
