// 5-stage pipelined RV32I-subset CPU: IF -> ID -> EX -> MEM -> WB.
// Same instruction set as single_cycle_top.
//   FORWARDING = 1 : EX/MEM and MEM/WB results are forwarded to the ALU; only load-use stalls.
//   FORWARDING = 0 : no forwarding; every RAW hazard stalls in ID (for CPI comparison).
// Branches are resolved in EX and predicted not-taken (2-cycle penalty when taken).
module pipeline_top #(
    parameter IMEM_FILE  = "",
    parameter IMEM_DEPTH = 256,
    parameter DMEM_DEPTH = 256,
    parameter FORWARDING = 1
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

    // ------------------------------------------------------------------
    // Hazard control
    // ------------------------------------------------------------------
    wire stall, pc_enable, if_id_enable, if_id_flush, id_ex_flush;
    wire branch_taken;
    wire [31:0] branch_target;

    // ==================================================================
    // IF
    // ==================================================================
    wire [31:0] pc_plus4 = pc_current + 32'd4;
    wire [31:0] pc_next  = branch_taken ? branch_target : pc_plus4;

    pc pc_reg (
        .clk(clk), .reset(reset), .enable(pc_enable),
        .next_pc(pc_next), .pc_out(pc_current)
    );

    instr_mem #(.MEM_FILE(IMEM_FILE), .DEPTH(IMEM_DEPTH)) imem (
        .clk(clk), .write_enable(imem_we), .write_address(imem_waddr), .write_data(imem_wdata),
        .read_address(pc_current), .instruction(instruction)
    );

    // ---------------- IF/ID ----------------
    wire        id_valid;
    wire [31:0] id_pc, id_instr;

    if_id if_id_reg (
        .clk(clk), .reset(reset), .enable(if_id_enable), .flush(if_id_flush),
        .pc_in(pc_current), .instr_in(instruction),
        .valid_out(id_valid), .pc_out(id_pc), .instr_out(id_instr)
    );

    // ==================================================================
    // ID
    // ==================================================================
    wire [6:0] id_opcode = id_instr[6:0];
    wire [4:0] id_rs1    = id_instr[19:15];
    wire [4:0] id_rs2    = id_instr[24:20];
    wire [4:0] id_rd     = id_instr[11:7];

    wire        id_reg_write, id_alu_src, id_mem_write, id_result_src, id_branch;
    wire [1:0]  id_imm_src, id_alu_op;
    wire [31:0] id_read_data1, id_read_data2, id_imm;

    // write-back signals (driven in WB, used by the register file here)
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_result;

    control_unit ctrl (
        .opcode(id_opcode),
        .reg_write(id_reg_write), .imm_src(id_imm_src), .alu_src(id_alu_src),
        .mem_write(id_mem_write), .result_src(id_result_src), .branch(id_branch), .alu_op(id_alu_op)
    );

    // BYPASS = 1: a register written in WB this cycle is read correctly in ID this cycle.
    reg_file #(.BYPASS(1)) rf (
        .clk(clk), .write_enable(wb_reg_write),
        .rs1(id_rs1), .rs2(id_rs2), .rd(wb_rd),
        .write_data(wb_result),
        .read_data1(id_read_data1), .read_data2(id_read_data2)
    );

    imm_gen immgen (
        .instruction(id_instr), .src(id_imm_src), .out(id_imm)
    );

    // Which source registers the instruction really reads (I-type/LW have no rs2:
    // those bits are immediate). Prevents false stalls.
    wire id_uses_rs1 = (id_opcode == 7'b0110011) || (id_opcode == 7'b0010011) ||
                       (id_opcode == 7'b0000011) || (id_opcode == 7'b0100011) ||
                       (id_opcode == 7'b1100011);
    wire id_uses_rs2 = (id_opcode == 7'b0110011) || (id_opcode == 7'b0100011) ||
                       (id_opcode == 7'b1100011);

    // ---------------- ID/EX ----------------
    wire        ex_valid, ex_reg_write, ex_alu_src, ex_mem_write, ex_result_src, ex_branch;
    wire [1:0]  ex_alu_op;
    wire [31:0] ex_pc, ex_instr, ex_read_data1, ex_read_data2, ex_imm;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;

    id_ex id_ex_reg (
        .clk(clk), .reset(reset), .flush(id_ex_flush),
        .valid_in(id_valid), .pc_in(id_pc), .instr_in(id_instr),
        .reg_write_in(id_reg_write), .alu_src_in(id_alu_src), .mem_write_in(id_mem_write),
        .result_src_in(id_result_src), .branch_in(id_branch), .alu_op_in(id_alu_op),
        .read_data1_in(id_read_data1), .read_data2_in(id_read_data2), .imm_in(id_imm),
        .rs1_in(id_rs1), .rs2_in(id_rs2), .rd_in(id_rd),
        .valid_out(ex_valid), .pc_out(ex_pc), .instr_out(ex_instr),
        .reg_write_out(ex_reg_write), .alu_src_out(ex_alu_src), .mem_write_out(ex_mem_write),
        .result_src_out(ex_result_src), .branch_out(ex_branch), .alu_op_out(ex_alu_op),
        .read_data1_out(ex_read_data1), .read_data2_out(ex_read_data2), .imm_out(ex_imm),
        .rs1_out(ex_rs1), .rs2_out(ex_rs2), .rd_out(ex_rd)
    );

    // ==================================================================
    // EX
    // ==================================================================
    wire        mem_valid, mem_reg_write, mem_mem_write, mem_result_src;
    wire [31:0] mem_pc, mem_instr, mem_alu_result, mem_write_data;
    wire [4:0]  mem_rd;

    wire [1:0]  forward_a, forward_b;
    wire [3:0]  ex_control_alu;
    wire [31:0] ex_alu_result;
    wire        ex_zero;
    wire [2:0]  ex_funct3 = ex_instr[14:12];

    forwarding_unit #(.ENABLE(FORWARDING)) fwd (
        .id_ex_rs1(ex_rs1), .id_ex_rs2(ex_rs2),
        .ex_mem_reg_write(mem_reg_write), .ex_mem_rd(mem_rd),
        .mem_wb_reg_write(wb_reg_write), .mem_wb_rd(wb_rd),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    wire [31:0] ex_operand_a = (forward_a == 2'b10) ? mem_alu_result :
                               (forward_a == 2'b01) ? wb_result      : ex_read_data1;
    wire [31:0] ex_operand_b = (forward_b == 2'b10) ? mem_alu_result :
                               (forward_b == 2'b01) ? wb_result      : ex_read_data2;
    wire [31:0] ex_alu_b     = ex_alu_src ? ex_imm : ex_operand_b;

    alu_control aluctrl (
        .alu_op(ex_alu_op), .funct3(ex_funct3), .funct7(ex_instr[31:25]),
        .control_alu(ex_control_alu)
    );

    ALU_RISCV alu (
        .a(ex_operand_a), .b(ex_alu_b), .control_alu(ex_control_alu),
        .result_alu(ex_alu_result), .zero(ex_zero)
    );

    // funct3 000 = BEQ (taken when equal), 001 = BNE (taken when not equal).
    // A dedicated equality comparator is used instead of the ALU's zero flag: it avoids
    // the 32-bit subtract carry chain on the critical path (EX -> branch -> flush) and
    // raised Fmax on iCE40 from 38.6 to ~49 MHz. Same result, since a - b == 0 <=> a == b.
    wire ex_equal = (ex_operand_a == ex_operand_b);
    assign branch_target = ex_pc + ex_imm;
    assign branch_taken  = ex_branch & ((ex_funct3 == 3'b000) ? ex_equal : ~ex_equal);

    hazard_unit #(.FORWARDING(FORWARDING)) hazard (
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        .id_uses_rs1(id_uses_rs1), .id_uses_rs2(id_uses_rs2),
        .id_ex_reg_write(ex_reg_write), .id_ex_mem_read(ex_result_src), .id_ex_rd(ex_rd),
        .ex_mem_reg_write(mem_reg_write), .ex_mem_rd(mem_rd),
        .branch_taken(branch_taken),
        .stall(stall), .pc_enable(pc_enable), .if_id_enable(if_id_enable),
        .if_id_flush(if_id_flush), .id_ex_flush(id_ex_flush)
    );

    // ---------------- EX/MEM ----------------
    // write_data is the forwarded rs2 value, so a store sees the newest data.
    ex_mem ex_mem_reg (
        .clk(clk), .reset(reset),
        .valid_in(ex_valid), .pc_in(ex_pc), .instr_in(ex_instr),
        .reg_write_in(ex_reg_write), .mem_write_in(ex_mem_write), .result_src_in(ex_result_src),
        .alu_result_in(ex_alu_result), .write_data_in(ex_operand_b), .rd_in(ex_rd),
        .valid_out(mem_valid), .pc_out(mem_pc), .instr_out(mem_instr),
        .reg_write_out(mem_reg_write), .mem_write_out(mem_mem_write), .result_src_out(mem_result_src),
        .alu_result_out(mem_alu_result), .write_data_out(mem_write_data), .rd_out(mem_rd)
    );

    // ==================================================================
    // MEM
    // ==================================================================
    wire [31:0] mem_read_data;

    data_mem #(.DEPTH(DMEM_DEPTH)) dmem (
        .clk(clk), .mem_write(mem_mem_write),
        .address(mem_alu_result), .write_data(mem_write_data), .read_data(mem_read_data)
    );

    // ---------------- MEM/WB ----------------
    wire        wb_valid, wb_result_src;
    wire [31:0] wb_pc, wb_instr, wb_alu_result, wb_read_data;

    mem_wb mem_wb_reg (
        .clk(clk), .reset(reset),
        .valid_in(mem_valid), .pc_in(mem_pc), .instr_in(mem_instr),
        .reg_write_in(mem_reg_write), .result_src_in(mem_result_src),
        .alu_result_in(mem_alu_result), .read_data_in(mem_read_data), .rd_in(mem_rd),
        .valid_out(wb_valid), .pc_out(wb_pc), .instr_out(wb_instr),
        .reg_write_out(wb_reg_write), .result_src_out(wb_result_src),
        .alu_result_out(wb_alu_result), .read_data_out(wb_read_data), .rd_out(wb_rd)
    );

    // ==================================================================
    // WB
    // ==================================================================
    assign wb_result = wb_result_src ? wb_read_data : wb_alu_result;

endmodule
