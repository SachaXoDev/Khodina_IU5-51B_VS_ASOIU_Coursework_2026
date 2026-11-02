// ============================================================================
// File: tb_washing_machine.v
// Module: tb_washing_machine
// Description: Automated Testbench for Grade 4 Task 23 (Washing Machine)
// ============================================================================
`timescale 1ns / 1ps

module tb_washing_machine;

    reg clk;
    reg rst;
    reg [15:0] ext_key_data;
    reg        ext_key_strobe;

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

    // Instantiate SoC Top
    soc_top #(
        .ROM_INIT_FILE("firmware/washing_machine.hex")
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

    // Clock generation: 100 MHz (period = 10ns)
    always #5 clk = ~clk;

    wire [4:0] stage_leds = ext_led_matrix[4:0];

    reg stage1_seen = 0;
    reg stage2_seen = 0;
    reg stage3_seen = 0;
    reg stage4_seen = 0;
    reg stage5_seen = 0;

    initial begin
        $dumpfile("sim/waveform_washing_machine.vcd");
        $dumpvars(0, tb_washing_machine);

        $display("================================================================");
        $display("=== STARTING SIMULATION: GRADE 4 WASHING MACHINE (TASK 23)   ===");
        $display("================================================================");

        clk = 0;
        rst = 1;
        ext_key_data = 16'h0000;
        ext_key_strobe = 1'b0;

        #30;
        @(negedge clk);
        rst = 0;

        // Monitor stages
        while (!cpu_halted && $time < 2000000) begin
            @(posedge clk);
            if (stage_leds == 5'b00001 && !stage1_seen) begin
                stage1_seen = 1;
                $display("[T=%0t] >>> STAGE 1 ACTIVE: WATER FILL (LED = 0x01, Timer = %0d)", $time, ext_rpn_display);
            end
            if (stage_leds == 5'b00010 && !stage2_seen) begin
                stage2_seen = 1;
                $display("[T=%0t] >>> STAGE 2 ACTIVE: DRUM WASH & ROTATION (LED = 0x02, Timer = %0d)", $time, ext_rpn_display);
            end
            if (stage_leds == 5'b00100 && !stage3_seen) begin
                stage3_seen = 1;
                $display("[T=%0t] >>> STAGE 3 ACTIVE: WATER DRAIN (LED = 0x04, Timer = %0d)", $time, ext_rpn_display);
            end
            if (stage_leds == 5'b01000 && !stage4_seen) begin
                stage4_seen = 1;
                $display("[T=%0t] >>> STAGE 4 ACTIVE: SPIN DRYING (LED = 0x08, Timer = %0d)", $time, ext_rpn_display);
            end
            if (stage_leds == 5'b10000 && !stage5_seen) begin
                stage5_seen = 1;
                $display("[T=%0t] >>> STAGE 5 ACTIVE: CYCLE COMPLETE (LED = 0x10, Timer = %0d)", $time, ext_rpn_display);
            end
        end

        #50;
        $display("----------------------------------------------------------------");
        $display("Final Verification of Washing Machine Cycle:");
        $display("  Stage 1 (Fill):  %s", stage1_seen ? "PASSED" : "FAILED");
        $display("  Stage 2 (Wash):  %s", stage2_seen ? "PASSED" : "FAILED");
        $display("  Stage 3 (Drain): %s", stage3_seen ? "PASSED" : "FAILED");
        $display("  Stage 4 (Spin):  %s", stage4_seen ? "PASSED" : "FAILED");
        $display("  Stage 5 (Done):  %s", stage5_seen ? "PASSED" : "FAILED");
        $display("  CPU Halted:      %s", cpu_halted ? "YES" : "NO");

        if (stage1_seen && stage2_seen && stage3_seen && stage4_seen && stage5_seen && cpu_halted) begin
            $display(">>> TEST PASSED: Full Washing Machine cycle verified successfully! <<<");
        end else begin
            $display(">>> TEST FAILED: Cycle did not execute completely. <<<");
        end
        $display("================================================================");
        $finish;
    end

endmodule
