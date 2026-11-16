module ex_stage (
    input  wire [31:0] p_out,
    input  wire [31:0] read_data1,
    input  wire [31:0] read_data2,
    input  wire [31:0] imm_out,
    input  wire        alu_src,
    input  wire        branch,
    input  wire [1:0]  alu_op,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    output wire [31:0] result_alu,
    output wire [31:0] pc_branch,
    output wire        pc_src
);

    wire [31:0] alu_in_b;
    wire [3:0]  control_alu;
    wire        zero;

    mux2 u_alu_src_mux (
        .in0 (read_data2),
        .in1 (imm_out),
        .sel (alu_src),
        .out (alu_in_b)
    );

    alu_control u_alu_control (
        .alu_op      (alu_op),
        .funct3      (funct3),
        .funct7      (funct7),
        .control_alu (control_alu)
    );

    ALU_RISCV u_alu (
        .a           (read_data1),
        .b           (alu_in_b),
        .control_alu (control_alu),
        .result_alu  (result_alu),
        .zero        (zero)
    );

    adder u_branch_adder (
        .a   (p_out),
        .b   (imm_out),
        .out (pc_branch)
    );

    branch_unit u_branch_unit (
        .branch (branch),
        .funct3 (funct3),
        .zero   (zero),
        .pc_src (pc_src)
    );

endmodule