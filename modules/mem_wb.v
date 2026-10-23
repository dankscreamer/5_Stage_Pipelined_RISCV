// MEM/WB pipeline register.
module mem_wb (
    input  wire        clk,
    input  wire        reset,

    input  wire        valid_in,
    input  wire [31:0] pc_in,
    input  wire [31:0] instr_in,
    input  wire        reg_write_in,
    input  wire        result_src_in,
    input  wire [31:0] alu_result_in,
    input  wire [31:0] read_data_in,
    input  wire [4:0]  rd_in,

    output reg         valid_out,
    output reg  [31:0] pc_out,
    output reg  [31:0] instr_out,
    output reg         reg_write_out,
    output reg         result_src_out,
    output reg  [31:0] alu_result_out,
    output reg  [31:0] read_data_out,
    output reg  [4:0]  rd_out
);

    always @(posedge clk) begin
        if (reset) begin
            valid_out      <= 1'b0;
            pc_out         <= 32'b0;
            instr_out      <= 32'h00000013;
            reg_write_out  <= 1'b0;
            result_src_out <= 1'b0;
            alu_result_out <= 32'b0;
            read_data_out  <= 32'b0;
            rd_out         <= 5'b0;
        end
        else begin
            valid_out      <= valid_in;
            pc_out         <= pc_in;
            instr_out      <= instr_in;
            reg_write_out  <= reg_write_in;
            result_src_out <= result_src_in;
            alu_result_out <= alu_result_in;
            read_data_out  <= read_data_in;
            rd_out         <= rd_in;
        end
    end

endmodule
