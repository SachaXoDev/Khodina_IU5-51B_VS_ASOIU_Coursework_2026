// ============================================================================
// File: mmio.v
// Module: mmio
// Description: Memory Mapped I/O Controller & Peripheral Registers
// ============================================================================
`timescale 1ns / 1ps

module mmio (
    input  wire        clk,
    input  wire        rst,

    // CPU Bus Interface
    input  wire [15:0] bus_addr,
    input  wire [15:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [15:0] bus_rdata,

    // External Interface (Testbench & Interactive Bridge)
    input  wire [15:0] ext_key_data,
    input  wire        ext_key_strobe,
    output wire [24:0] ext_led_matrix,
    output wire [2:0]  ext_cursor_x,
    output wire [2:0]  ext_cursor_y,
    output wire [15:0] ext_moves_count,
    output wire        ext_game_won,
    output wire [15:0] ext_rpn_display,
    output reg         ext_sim_halt
);

    // MMIO Registers
    reg [4:0]  led_row0;          // 5x5 LED matrix rows (0xFF10 - 0xFF14)
    reg [4:0]  led_row1;
    reg [4:0]  led_row2;
    reg [4:0]  led_row3;
    reg [4:0]  led_row4;
    reg [2:0]  cursor_x;          // Cursor X (0xFF15 [2:0])
    reg [2:0]  cursor_y;          // Cursor Y (0xFF15 [5:3])
    reg [15:0] move_counter;      // Moves count (0xFF16)
    reg [15:0] game_status;       // 0=play, 1=win (0xFF17)
    reg [15:0] rpn_display;       // RPN Calc display (0xFF20)
    reg [15:0] cycle_timer;       // Clock cycles (0xFFFE)

    // Keyboard buffer
    reg [15:0] key_buffer;
    reg        key_available;

    // External Outputs wiring
    assign ext_led_matrix  = {led_row4, led_row3, led_row2, led_row1, led_row0};
    assign ext_cursor_x    = cursor_x;
    assign ext_cursor_y    = cursor_y;
    assign ext_moves_count = move_counter;
    assign ext_game_won    = (game_status != 16'h0000);
    assign ext_rpn_display = rpn_display;

    // Timer logic
    always @(posedge clk) begin
        if (rst) begin
            cycle_timer <= 16'h0000;
        end else begin
            cycle_timer <= cycle_timer + 16'd1;
        end
    end

    // External Keyboard Strobe Latch
    always @(posedge clk) begin
        if (rst) begin
            key_buffer    <= 16'h0000;
            key_available <= 1'b0;
        end else if (ext_key_strobe) begin
            key_buffer    <= ext_key_data;
            key_available <= 1'b1;
        end else if (bus_re && (bus_addr == 16'hFF01)) begin
            // Reading key data acknowledges and clears available flag
            key_available <= 1'b0;
        end
    end

    // MMIO Write Decoder
    always @(posedge clk) begin
        if (rst) begin
            led_row0     <= 5'b00000;
            led_row1     <= 5'b00000;
            led_row2     <= 5'b00000;
            led_row3     <= 5'b00000;
            led_row4     <= 5'b00000;
            cursor_x     <= 3'd2; // Center (2, 2)
            cursor_y     <= 3'd2;
            move_counter <= 16'h0000;
            game_status  <= 16'h0000;
            rpn_display  <= 16'h0000;
            ext_sim_halt <= 1'b0;
        end else if (bus_we) begin
            case (bus_addr)
                16'hFF00: begin
                    // UART console output in simulation
                    $write("%c", bus_wdata[7:0]);
                end
                16'hFF01: begin
                    // Clear / write key buffer
                    key_buffer    <= bus_wdata;
                    key_available <= 1'b0;
                end
                16'hFF10: led_row0     <= bus_wdata[4:0];
                16'hFF11: led_row1     <= bus_wdata[4:0];
                16'hFF12: led_row2     <= bus_wdata[4:0];
                16'hFF13: led_row3     <= bus_wdata[4:0];
                16'hFF14: led_row4     <= bus_wdata[4:0];
                16'hFF15: begin
                    cursor_x <= bus_wdata[2:0];
                    cursor_y <= bus_wdata[5:3];
                end
                16'hFF16: move_counter <= bus_wdata;
                16'hFF17: game_status  <= bus_wdata;
                16'hFF20: rpn_display  <= bus_wdata;
                16'hFFFF: ext_sim_halt <= bus_wdata[0];
                default: ;
            endcase
        end
    end

    // MMIO Read Multiplexer
    always @(*) begin
        case (bus_addr)
            16'hFF00: bus_rdata = 16'h0000;
            16'hFF01: bus_rdata = key_buffer;
            16'hFF02: bus_rdata = {15'b0, key_available};
            16'hFF10: bus_rdata = {11'b0, led_row0};
            16'hFF11: bus_rdata = {11'b0, led_row1};
            16'hFF12: bus_rdata = {11'b0, led_row2};
            16'hFF13: bus_rdata = {11'b0, led_row3};
            16'hFF14: bus_rdata = {11'b0, led_row4};
            16'hFF15: bus_rdata = {10'b0, cursor_y, cursor_x};
            16'hFF16: bus_rdata = move_counter;
            16'hFF17: bus_rdata = game_status;
            16'hFF20: bus_rdata = rpn_display;
            16'hFFFE: bus_rdata = cycle_timer;
            16'hFFFF: bus_rdata = {15'b0, ext_sim_halt};
            default:  bus_rdata = 16'h0000;
        endcase
    end

endmodule
