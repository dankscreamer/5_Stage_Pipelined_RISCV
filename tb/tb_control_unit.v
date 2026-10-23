`timescale 1ns/1ps
module tb_control_unit;
    reg  [6:0] opcode;
    wire       reg_write, alu_src, mem_write, result_src, branch;
    wire [1:0] imm_src, alu_op;
    integer errors = 0, checks = 0;

    control_unit dut (.opcode(opcode), .reg_write(reg_write), .imm_src(imm_src), .alu_src(alu_src),
                      .mem_write(mem_write), .result_src(result_src), .branch(branch), .alu_op(alu_op));

    // expected = {reg_write, imm_src[1:0], alu_src, mem_write, result_src, branch, alu_op[1:0]}
    task check(input [6:0] op, input [8:0] expected);
        begin
            opcode = op; #1;
            checks = checks + 1;
            if ({reg_write, imm_src, alu_src, mem_write, result_src, branch, alu_op} !== expected) begin
                $display("FAIL opcode=%b -> %b (expected %b)", op,
                         {reg_write, imm_src, alu_src, mem_write, result_src, branch, alu_op}, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        //                   rw imm as mw rs br aluop
        check(7'b0110011, 9'b1_00_0_0_0_0_10); // R-type
        check(7'b0010011, 9'b1_00_1_0_0_0_11); // I-type ALU
        check(7'b0000011, 9'b1_00_1_0_1_0_00); // LW
        check(7'b0100011, 9'b0_01_1_1_0_0_00); // SW
        check(7'b1100011, 9'b0_10_0_0_0_1_01); // BEQ/BNE
        check(7'b0000000, 9'b0_00_0_0_0_0_00); // unknown -> NOP
        check(7'b1101111, 9'b0_00_0_0_0_0_00); // JAL not supported -> NOP
        if (errors == 0) $display("RESULT: PASS tb_control_unit (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_control_unit (%0d errors)", errors);
        $finish;
    end
endmodule
