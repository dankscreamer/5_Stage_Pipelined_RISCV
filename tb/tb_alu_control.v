`timescale 1ns/1ps
module tb_alu_control;
    reg  [1:0] alu_op;
    reg  [2:0] funct3;
    reg  [6:0] funct7;
    wire [3:0] ctrl;
    integer errors = 0, checks = 0;

    alu_control dut (.alu_op(alu_op), .funct3(funct3), .funct7(funct7), .control_alu(ctrl));

    task check(input [1:0] op, input [2:0] f3, input [6:0] f7, input [3:0] expected);
        begin
            alu_op = op; funct3 = f3; funct7 = f7; #1;
            checks = checks + 1;
            if (ctrl !== expected) begin
                $display("FAIL alu_op=%b funct3=%b funct7=%b -> %b (expected %b)", op, f3, f7, ctrl, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        check(2'b00, 3'b010, 7'h00, 4'b0010); // LW/SW -> ADD
        check(2'b00, 3'b010, 7'h7F, 4'b0010); // offset bits must not matter
        check(2'b01, 3'b000, 7'h00, 4'b0110); // BEQ -> SUB
        check(2'b01, 3'b001, 7'h7F, 4'b0110); // BNE -> SUB
        check(2'b10, 3'b000, 7'h00, 4'b0010); // ADD
        check(2'b10, 3'b000, 7'h20, 4'b0110); // SUB
        check(2'b10, 3'b111, 7'h00, 4'b0000); // AND
        check(2'b10, 3'b110, 7'h00, 4'b0001); // OR
        check(2'b10, 3'b100, 7'h00, 4'b0100); // XOR
        check(2'b11, 3'b000, 7'h00, 4'b0010); // ADDI
        check(2'b11, 3'b000, 7'h7F, 4'b0010); // ADDI x, x, -1: must stay ADD (was the SUB bug)
        check(2'b11, 3'b000, 7'h20, 4'b0010); // ADDI with imm bit 10 set
        check(2'b11, 3'b111, 7'h7F, 4'b0000); // ANDI
        check(2'b11, 3'b110, 7'h7F, 4'b0001); // ORI
        check(2'b11, 3'b100, 7'h7F, 4'b0100); // XORI
        if (errors == 0) $display("RESULT: PASS tb_alu_control (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_alu_control (%0d errors)", errors);
        $finish;
    end
endmodule
