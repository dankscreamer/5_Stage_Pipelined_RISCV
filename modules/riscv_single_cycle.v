`include "include.vh"
`include "include_stage.vh"


module riscv_single_cycle (
    input wire clk,
    input wire rst
);

    wire [31:0] p_out;
    wire [31:0] instruction;
    wire [31:0] pc_branch;
    wire        pc_src;

    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] imm_out;
    wire        reg_write;
    wire        alu_src;
    wire        mem_read;
    wire        mem_write;
    wire        mem_to_reg;
    wire        branch;
    wire [1:0]  alu_op;

    wire [31:0] result_alu;
    wire [31:0] read_data;
    wire [31:0] write_data;

    if_stage u_if_stage (
        .clk         (clk),
        .rst         (rst),
        .pc_src      (pc_src),
        .pc_branch   (pc_branch),
        .p_out       (p_out),
        .instruction (instruction)
    );

    id_stage u_id_stage (
        .clk         (clk),
        .rst         (rst),
        .instruction (instruction),
        .write_data  (write_data),
        .read_data1  (read_data1),
        .read_data2  (read_data2),
        .imm_out     (imm_out),
        .reg_write   (reg_write),
        .alu_src     (alu_src),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .mem_to_reg  (mem_to_reg),
        .branch      (branch),
        .alu_op      (alu_op)
    );

    ex_stage u_ex_stage (
        .p_out       (p_out),
        .read_data1  (read_data1),
        .read_data2  (read_data2),
        .imm_out     (imm_out),
        .alu_src     (alu_src),
        .branch      (branch),
        .alu_op      (alu_op),
        .funct3      (instruction[14:12]),
        .funct7      (instruction[31:25]),
        .result_alu  (result_alu),
        .pc_branch   (pc_branch),
        .pc_src      (pc_src)
    );

    mem_stage u_mem_stage (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write && !rst),
        .address    (result_alu),
        .write_data (read_data2),
        .read_data  (read_data)
    );

    wb_stage u_wb_stage (
        .result_alu (result_alu),
        .read_data  (read_data),
        .mem_to_reg (mem_to_reg),
        .write_data (write_data)
    );

endmodule
