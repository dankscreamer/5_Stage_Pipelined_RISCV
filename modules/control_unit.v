// Main decoder: opcode -> datapath control signals.
//   imm_src    : 00 I-type, 01 S-type, 10 B-type, 11 J-type (matches imm_gen)
//   alu_src    : 0 = rs2, 1 = immediate
//   result_src : 0 = ALU result, 1 = data memory
//   alu_op     : see alu_control.v
// Unknown opcodes (including all-zero words) produce no writes, i.e. behave as a NOP.
module control_unit (
    input  wire [6:0] opcode,
    output reg        reg_write,
    output reg  [1:0] imm_src,
    output reg        alu_src,
    output reg        mem_write,
    output reg        result_src,
    output reg        branch,
    output reg  [1:0] alu_op
);

    localparam OP_R_TYPE = 7'b0110011;
    localparam OP_I_ALU  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;

    always @(*) begin
        reg_write  = 1'b0;
        imm_src    = 2'b00;
        alu_src    = 1'b0;
        mem_write  = 1'b0;
        result_src = 1'b0;
        branch     = 1'b0;
        alu_op     = 2'b00;

        if (opcode == OP_R_TYPE) begin
            reg_write = 1'b1;
            alu_op    = 2'b10;
        end
        else if (opcode == OP_I_ALU) begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            alu_op    = 2'b11;
        end
        else if (opcode == OP_LOAD) begin
            reg_write  = 1'b1;
            alu_src    = 1'b1;
            result_src = 1'b1;
        end
        else if (opcode == OP_STORE) begin
            imm_src   = 2'b01;
            alu_src   = 1'b1;
            mem_write = 1'b1;
        end
        else if (opcode == OP_BRANCH) begin
            imm_src = 2'b10;
            branch  = 1'b1;
            alu_op  = 2'b01;
        end
    end

endmodule
