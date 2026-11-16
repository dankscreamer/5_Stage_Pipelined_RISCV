`include "./include.vh"

module id_stage (
    input  wire        clk,
    input  wire [31:0] instruction,
    input  wire [31:0] write_data,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    output wire [31:0] imm_out,
    output wire        reg_write,
    output wire        alu_src,
    output wire        mem_read,
    output wire        mem_write,
    output wire        mem_to_reg,
    output wire        branch,
    output wire [1:0]  alu_op
);

    wire [1:0] imm_src;

    control_unit u_control_unit (
        .opcode     (instruction[6:0]),
        .reg_write  (reg_write),
        .imm_src    (imm_src),
        .alu_src    (alu_src),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .mem_to_reg (mem_to_reg),
        .branch     (branch),
        .alu_op     (alu_op)
    );

    reg_file u_reg_file (
        .clk          (clk),
        .write_enable (reg_write),
        .rs1          (instruction[19:15]),
        .rs2          (instruction[24:20]),
        .rd           (instruction[11:7]),
        .write_data   (write_data),
        .read_data1   (read_data1),
        .read_data2   (read_data2)
    );

    imm_gen u_imm_gen (
        .instruction (instruction),
        .src         (imm_src),
        .out         (imm_out)
    );

endmodule
