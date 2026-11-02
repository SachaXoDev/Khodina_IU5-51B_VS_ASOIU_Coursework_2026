// ============================================================================
// File: tb_sokoban.v
// Module: tb_sokoban
// Description: Automated Testbench for Grade 5 Task 18 (Sokoban + PUSH_LOGIC)
// ============================================================================
`timescale 1ns / 1ps

module tb_sokoban;

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
        .ROM_INIT_FILE("firmware/sokoban.hex")
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

    // Wait until CPU executes a read from MMIO[0xFF02] (keyboard polling)
    task wait_for_input_poll;
        begin
            while (!(dut.u_mmio.bus_re && dut.u_mmio.bus_addr == 16'hFF02) && !cpu_halted) @(posedge clk);
            repeat (5) @(posedge clk);
        end
    endtask

    // Bulletproof handshake task
    task send_key(input [15:0] k);
        begin
            wait_for_input_poll();

            @(posedge clk);
            ext_key_data   <= k;
            ext_key_strobe <= 1'b1;
            @(posedge clk);
            ext_key_strobe <= 1'b0;
            @(posedge clk);

            // Wait until CPU acknowledges key
            while (dut.u_mmio.key_available && !cpu_halted) @(posedge clk);

            // Wait until move processing finishes and CPU returns to polling input
            wait_for_input_poll();
            repeat (20) @(posedge clk);
        end
    endtask

    integer cycles;

    initial begin
        $dumpfile("sim/waveform_sokoban.vcd");
        $dumpvars(0, tb_sokoban);

        $display("================================================================");
        $display("=== STARTING SIMULATION: GRADE 5 SOKOBAN (TASK 18)           ===");
        $display("=== WITH PUSH_LOGIC HARDWARE ACCELERATION                    ===");
        $display("================================================================");

        clk = 0;
        rst = 1;
        ext_key_data = 16'h0000;
        ext_key_strobe = 1'b0;

        #40;
        @(negedge clk);
        rst = 0;

        // Wait until CPU finishes map initialization and reaches input poll
        wait_for_input_poll();

        $display("[T=%0t] Initial map rendered to terminal.", $time);
        $display("[T=%0t] Move 1: Player steps Down (Key 's')...", $time);
        send_key("s");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 2: Player steps Down (Key 's')...", $time);
        send_key("s");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 3: Player steps Down (Key 's')...", $time);
        send_key("s");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 4: Player steps Down (Key 's')...", $time);
        send_key("s");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 5: Player steps Right toward Box (Key 'd')...", $time);
        send_key("d");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 6: Player pushes Box Right (Key 'd')...", $time);
        send_key("d");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 7: Player pushes Box Right (Key 'd')...", $time);
        send_key("d");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 8: Player pushes Box Right under Goal column (Key 'd')...", $time);
        send_key("d");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 9: Player steps Down to loop around (Key 's')...", $time);
        send_key("s");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 10: Player steps Right under Box (Key 'd')...", $time);
        send_key("d");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 11: Player pushes Box Up (Key 'w')...", $time);
        send_key("w");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);

        $display("[T=%0t] Move 12: Player pushes Box Up onto Goal (Key 'w')...", $time);
        send_key("w");
        $display("  Moves count: %0d, Won: %0d", ext_moves_count, ext_game_won);
        // Verification of victory
        if (ext_game_won) begin
            $display("================================================================");
            $display("  VICTORY CONFIRMED: BOX IS ON GOAL (*) IN SOKOBAN!            ");
            $display("  MMIO GAME_STATUS = 1, MOVE_COUNTER = %0d                     ", ext_moves_count);
            $display("================================================================");
        end else begin
            $display(">>> TEST FAILED: Box did not reach goal or win flag not set! <<<");
        end

        // Quit game cleanly
        $display("[T=%0t] Sending 'q' to quit game...", $time);
        @(posedge clk);
        ext_key_data   <= "q";
        ext_key_strobe <= 1'b1;
        @(posedge clk);
        ext_key_strobe <= 1'b0;

        cycles = 0;
        while (!cpu_halted && cycles < 500) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (cpu_halted) begin
            $display("[T=%0t] CPU cleanly halted after gameplay session.", $time);
        end
        $display("================================================================");
        $finish;
    end

endmodule
