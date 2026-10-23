// ID/EX pipeline register. flush = 1 inserts a bubble: valid and every control
// signal that changes architectural state (reg_write, mem_write, branch) are cleared.
module id_ex (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,

    input  wire        valid_in,
    input  wire [31:0] pc_in,
    input  wire [31:0] instr_in,
    input  wire        reg_write_in,
    input  wire        alu_src_in,
    input  wire        mem_write_in,
    input  wire        result_src_in,
    input  wire        branch_in,
    input  wire [1:0]  alu_op_in,
    input  wire [31:0] read_data1_in,
    input  wire [31:0] read_data2_in,
    input  wire [31:0] imm_in,
    input  wire [4:0]  rs1_in,
    input  wire [4:0]  rs2_in,
    input  wire [4:0]  rd_in,

    output reg         valid_out,
    output reg  [31:0] pc_out,
    output reg  [31:0] instr_out,
    output reg         reg_write_out,
    output reg         alu_src_out,
    output reg         mem_write_out,
    output reg         result_src_out,
    output reg         branch_out,
    output reg  [1:0]  alu_op_out,
    output reg  [31:0] read_data1_out,
    output reg  [31:0] read_data2_out,
    output reg  [31:0] imm_out,
    output reg  [4:0]  rs1_out,
    output reg  [4:0]  rs2_out,
    output reg  [4:0]  rd_out
);

    always @(posedge clk) begin
        if (reset || flush) begin
            valid_out      <= 1'b0;
            pc_out         <= 32'b0;
            instr_out      <= 32'h00000013;
            reg_write_out  <= 1'b0;
            alu_src_out    <= 1'b0;
            mem_write_out  <= 1'b0;
            result_src_out <= 1'b0;
            branch_out     <= 1'b0;
            alu_op_out     <= 2'b00;
            read_data1_out <= 32'b0;
            read_data2_out <= 32'b0;
            imm_out        <= 32'b0;
            rs1_out        <= 5'b0;
            rs2_out        <= 5'b0;
            rd_out         <= 5'b0;
        end
        else begin
            valid_out      <= valid_in;
            pc_out         <= pc_in;
            instr_out      <= instr_in;
            reg_write_out  <= reg_write_in;
            alu_src_out    <= alu_src_in;
            mem_write_out  <= mem_write_in;
            result_src_out <= result_src_in;
            branch_out     <= branch_in;
            alu_op_out     <= alu_op_in;
            read_data1_out <= read_data1_in;
            read_data2_out <= read_data2_in;
            imm_out        <= imm_in;
            rs1_out        <= rs1_in;
            rs2_out        <= rs2_in;
            rd_out         <= rd_in;
        end
    end

endmodule
