// ============================================================================
// File: cpu_core.v
// Module: cpu_core
// Description: Multi-cycle FSM Processor Core for KOCTA-16 Architecture
// ============================================================================
`timescale 1ns / 1ps

module cpu_core (
    input  wire        clk,
    input  wire        rst,

    // Instruction ROM Interface
    output wire [7:0]  rom_addr,
    input  wire [15:0] rom_data,

    // Data Memory / MMIO Interface
    output wire [15:0] mem_addr,
    output wire [15:0] mem_wdata,
    output reg         mem_we,
    output reg         mem_re,
    input  wire [15:0] mem_rdata,

    // CPU Status
    output reg         halted,
    output wire [7:0]  current_pc,
    output wire [15:0] r15_flags
);

    // FSM States
    localparam S_FETCH    = 2'd0;
    localparam S_EXECUTE  = 2'd1;
    localparam S_MEM_READ = 2'd2;
    localparam S_HALTED   = 2'd3;

    reg [1:0] state;

    // Registers
    reg [7:0]  pc;
    reg [15:0] ir;
    reg        flag_z;
    reg        flag_n;

    assign current_pc = pc;
    assign rom_addr   = pc;
    assign r15_flags  = {14'b0, flag_n, flag_z};

    // Instruction Decode Fields
    wire [3:0] opcode = ir[15:12];
    wire [3:0] rd     = ir[11:8];
    wire [3:0] rs1    = ir[7:4];
    wire [3:0] rs2    = ir[3:0];
    wire [7:0] imm8   = ir[7:0];
    wire [3:0] offset4= ir[3:0];
    wire [3:0] cond   = ir[11:8];
    wire [7:0] target = ir[7:0];

    // Register File Control Signals
    reg         rf_we;
    reg  [3:0]  rf_waddr;
    reg  [15:0] rf_wdata;
    wire [3:0]  rf_raddr1;
    wire [3:0]  rf_raddr2;
    wire [15:0] rf_rdata1;
    wire [15:0] rf_rdata2;

    // Port 1 reads rs1 (or R14 for RET); Port 2 reads rs2 (or rd for STORE / LDH)
    assign rf_raddr1 = (opcode == 4'hB && cond == 4'h6) ? 4'hE : rs1;
    assign rf_raddr2 = (opcode == 4'hA || opcode == 4'h8) ? rd : rs2;
    register_file u_regfile (
        .clk(clk),
        .rst(rst),
        .we(rf_we),
        .read_addr1(rf_raddr1),
        .read_addr2(rf_raddr2),
        .write_addr(rf_waddr),
        .write_data(rf_wdata),
        .read_data1(rf_rdata1),
        .read_data2(rf_rdata2)
    );

    // ALU Signals
    wire [3:0]  alu_op = opcode;
    reg  [15:0] alu_b;
    wire [15:0] alu_result;
    wire        alu_z;
    wire        alu_n;

    always @(*) begin
        case (opcode)
            4'hC, 4'hD: alu_b = {12'b0, offset4}; // Shift amount in offset4
            default:    alu_b = rf_rdata2;
        endcase
    end

    alu u_alu (
        .alu_op(alu_op),
        .a(rf_rdata1),
        .b(alu_b),
        .result(alu_result),
        .flag_z(alu_z),
        .flag_n(alu_n)
    );

    // Memory Address generation
    assign mem_addr  = rf_rdata1 + {12'b0, offset4};
    assign mem_wdata = rf_rdata2; // Data to store comes from rd (via rf_raddr2)

    // Branch condition evaluation
    reg branch_taken;
    always @(*) begin
        case (cond)
            4'h0: branch_taken = (flag_z == 1'b1); // JZ / BEQ
            4'h1: branch_taken = (flag_z == 1'b0); // JNZ / BNE
            4'h2: branch_taken = (flag_n == 1'b1); // JLT / BLT
            4'h3: branch_taken = (flag_n == 1'b0); // JGE / BGE
            4'h4: branch_taken = 1'b1;            // JMP unconditional
            4'h5: branch_taken = 1'b1;            // CALL
            4'h6: branch_taken = 1'b1;            // RET
            default: branch_taken = 1'b0;
        endcase
    end

    // Main Control FSM
    always @(posedge clk) begin
        if (rst) begin
            state    <= S_FETCH;
            pc       <= 8'h00;
            ir       <= 16'h0000;
            flag_z   <= 1'b0;
            flag_n   <= 1'b0;
            halted   <= 1'b0;
            rf_we    <= 1'b0;
            rf_waddr <= 4'h0;
            rf_wdata <= 16'h0000;
            mem_we   <= 1'b0;
            mem_re   <= 1'b0;
        end else begin
            // Default pulse deassertions
            rf_we  <= 1'b0;
            mem_we <= 1'b0;
            mem_re <= 1'b0;

            case (state)
                S_FETCH: begin
                    ir    <= rom_data;
                    state <= S_EXECUTE;
                end

                S_EXECUTE: begin
                    case (opcode)
                        // ALU Arithmetic/Logic: ADD, SUB, AND, OR, XOR, CROSS_XOR
                        4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'hF: begin
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            rf_wdata <= alu_result;
                            flag_z   <= alu_z;
                            flag_n   <= alu_n;
                            pc       <= pc + 8'd1;
                            state    <= S_FETCH;
                        end

                        // CMP: Compare Rs1 and Rs2, updates flags only
                        4'h6: begin
                            flag_z <= (rf_rdata1 == rf_rdata2);
                            flag_n <= ($signed(rf_rdata1) < $signed(rf_rdata2));
                            pc     <= pc + 8'd1;
                            state  <= S_FETCH;
                        end

                        // LDI: Load Immediate lower byte
                        4'h7: begin
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            rf_wdata <= {8'h00, imm8};
                            pc       <= pc + 8'd1;
                            state    <= S_FETCH;
                        end

                        // LDH: Load Immediate upper byte
                        4'h8: begin
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            rf_wdata <= {imm8, rf_rdata2[7:0]}; // rf_rdata2 or current value
                            pc       <= pc + 8'd1;
                            state    <= S_FETCH;
                        end

                        // LOAD: Memory read
                        4'h9: begin
                            mem_re <= 1'b1;
                            state  <= S_MEM_READ;
                        end

                        // STORE: Memory write
                        4'hA: begin
                            mem_we <= 1'b1;
                            pc     <= pc + 8'd1;
                            state  <= S_FETCH;
                        end

                        // BRANCH / JUMP / CALL / RET
                        4'hB: begin
                            if (cond == 4'h5) begin
                                // CALL: Save return address (PC + 1) in R14, jump to target
                                rf_we    <= 1'b1;
                                rf_waddr <= 4'hE; // R14 (LR)
                                rf_wdata <= {8'h00, pc + 8'd1};
                                pc       <= target;
                            end else if (cond == 4'h6) begin
                                // RET: Jump to address in R14
                                pc <= rf_rdata1[7:0]; // Rs1 should be R14 (0xE)
                            end else if (branch_taken) begin
                                pc <= target;
                            end else begin
                                pc <= pc + 8'd1;
                            end
                            state <= S_FETCH;
                        end

                        // Shifts: SHL, SHR
                        4'hC, 4'hD: begin
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            rf_wdata <= alu_result;
                            flag_z   <= alu_z;
                            flag_n   <= alu_n;
                            pc       <= pc + 8'd1;
                            state    <= S_FETCH;
                        end

                        // 4'hE: HALT if Rd==0, otherwise PUSH_LOGIC hardware acceleration
                        4'hE: begin
                            if (rd == 4'h0 && (imm8 == 8'h00 || imm8 == 8'hFF)) begin
                                halted <= 1'b1;
                                state  <= S_HALTED;
                            end else begin
                                rf_we    <= 1'b1;
                                rf_waddr <= rd;
                                rf_wdata <= alu_result;
                                flag_z   <= alu_z;
                                flag_n   <= alu_n;
                                pc       <= pc + 8'd1;
                                state    <= S_FETCH;
                            end
                        end

                        // NOP / Default
                        default: begin
                            pc    <= pc + 8'd1;
                            state <= S_FETCH;
                        end
                    endcase
                end

                S_MEM_READ: begin
                    // Write loaded memory data into Rd
                    rf_we    <= 1'b1;
                    rf_waddr <= rd;
                    rf_wdata <= mem_rdata;
                    pc       <= pc + 8'd1;
                    state    <= S_FETCH;
                end

                S_HALTED: begin
                    // Remain halted
                    state <= S_HALTED;
                end
            endcase
        end
    end

endmodule
