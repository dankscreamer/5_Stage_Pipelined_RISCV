// Single-cycle RV32I-subset CPU: ADD SUB AND OR XOR ADDI ANDI ORI XORI LW SW BEQ BNE.
// Every instruction completes in one clock, so CPI = 1 by construction. This is the
// reference design the pipelined CPU is verified and benchmarked against.
module single_cycle_top #(
    parameter IMEM_FILE  = "",
    parameter IMEM_DEPTH = 256,
    parameter DMEM_DEPTH = 256
) (
    input  wire        clk,
    input  wire        reset,
    // program-load port into instruction memory (tie imem_we to 0 in normal use)
    input  wire        imem_we,
    input  wire [31:0] imem_waddr,
    input  wire [31:0] imem_wdata,
    output wire [31:0] pc_current,
    output wire [31:0] instruction
);

    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    wire [31:0] branch_target;

    wire        reg_write;
    wire [1:0]  imm_src;
    wire        alu_src;
    wire        mem_write;
    wire        result_src;
    wire        branch;
    wire [1:0]  alu_op;
    wire [3:0]  control_alu;

    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] imm_ext;
    wire [31:0] alu_b;
    wire [31:0] alu_result;
    wire        zero;
    wire [31:0] mem_read_data;
    wire [31:0] result;

    wire [2:0]  funct3 = instruction[14:12];
    wire        branch_taken;

    // ---------------- IF ----------------
    pc pc_reg (
        .clk(clk), .reset(reset), .enable(1'b1),
        .next_pc(pc_next), .pc_out(pc_current)
    );

    instr_mem #(.MEM_FILE(IMEM_FILE), .DEPTH(IMEM_DEPTH)) imem (
        .clk(clk), .write_enable(imem_we), .write_address(imem_waddr), .write_data(imem_wdata),
        .read_address(pc_current), .instruction(instruction)
    );

    assign pc_plus4 = pc_current + 32'd4;

    // ---------------- ID ----------------
    control_unit ctrl (
        .opcode(instruction[6:0]),
        .reg_write(reg_write), .imm_src(imm_src), .alu_src(alu_src),
        .mem_write(mem_write), .result_src(result_src), .branch(branch), .alu_op(alu_op)
    );

    reg_file #(.BYPASS(0)) rf (
        .clk(clk), .write_enable(reg_write),
        .rs1(instruction[19:15]), .rs2(instruction[24:20]), .rd(instruction[11:7]),
        .write_data(result),
        .read_data1(read_data1), .read_data2(read_data2)
    );

    imm_gen immgen (
        .instruction(instruction), .src(imm_src), .out(imm_ext)
    );

    // ---------------- EX ----------------
    alu_control aluctrl (
        .alu_op(alu_op), .funct3(funct3), .funct7(instruction[31:25]),
        .control_alu(control_alu)
    );

    assign alu_b = alu_src ? imm_ext : read_data2;

    ALU_RISCV alu (
        .a(read_data1), .b(alu_b), .control_alu(control_alu),
        .result_alu(alu_result), .zero(zero)
    );

    assign branch_target = pc_current + imm_ext;
    // funct3 000 = BEQ (taken when equal), 001 = BNE (taken when not equal).
    // Dedicated equality comparator (same as the pipelined CPU) instead of the ALU zero flag.
    wire equal = (read_data1 == read_data2);
    assign branch_taken  = branch & ((funct3 == 3'b000) ? equal : ~equal);
    assign pc_next       = branch_taken ? branch_target : pc_plus4;

    // ---------------- MEM ----------------
    data_mem #(.DEPTH(DMEM_DEPTH)) dmem (
        .clk(clk), .mem_write(mem_write),
        .address(alu_result), .write_data(read_data2), .read_data(mem_read_data)
    );

    // ---------------- WB ----------------
    assign result = result_src ? mem_read_data : alu_result;

endmodule
