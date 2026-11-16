`include "./include.vh"



module wb_stage (
    input  wire [31:0] result_alu,
    input  wire [31:0] read_data,
    input  wire        mem_to_reg,
    output wire [31:0] write_data
);

    mux2 u_wb_mux (
        .in0 (result_alu),
        .in1 (read_data),
        .sel (mem_to_reg),
        .out (write_data)
    );

endmodule


