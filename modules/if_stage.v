module if_stage (
    input  wire        clk,
    input  wire        rst,
    input  wire        pc_src,
    input  wire [31:0] pc_branch,
    output wire [31:0] p_out,
    output wire [31:0] instruction
);

    wire [31:0] pc_plus_4;
    wire [31:0] p_nxt;

    adder u_pc_plus_4 (
        .a   (p_out),
        .b   (32'd4),
        .out (pc_plus_4)
    );

    mux2 u_pc_mux (
        .in0 (pc_plus_4),
        .in1 (pc_branch),
        .sel (pc_src),
        .out (p_nxt)
    );

    pc u_pc (
        .clk   (clk),
        .rst   (rst),
        .p_nxt (p_nxt),
        .p_out (p_out)
    );

    instr_mem u_instr_mem (
        .read_address (p_out),
        .instruction  (instruction)
    );

endmodule