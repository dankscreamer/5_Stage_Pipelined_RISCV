`timescale 1ns/1ps
module tb_alu;
    reg  [31:0] a, b;
    reg  [3:0]  ctrl;
    wire [31:0] y;
    wire        zero;
    integer errors = 0, i;

    ALU_RISCV dut (.a(a), .b(b), .control_alu(ctrl), .result_alu(y), .zero(zero));

    task check(input [31:0] expected);
        begin
            #1;
            if (y !== expected || zero !== (expected == 0)) begin
                $display("FAIL ctrl=%b a=%h b=%h -> y=%h zero=%b (expected %h)", ctrl, a, b, y, zero, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // directed edge cases
        a = 32'h7FFFFFFF; b = 1;            ctrl = 4'b0010; check(32'h80000000); // signed overflow wraps
        a = 0;            b = 1;            ctrl = 4'b0110; check(32'hFFFFFFFF); // borrow
        a = 32'h1234;     b = 32'h1234;     ctrl = 4'b0110; check(0);            // equal -> zero (BEQ)
        a = 32'hF0F0F0F0; b = 32'h0FF00FF0; ctrl = 4'b0000; check(32'h00F000F0);
        a = 32'hF0F0F0F0; b = 32'h0FF00FF0; ctrl = 4'b0001; check(32'hFFF0FFF0);
        a = 32'hF0F0F0F0; b = 32'h0FF00FF0; ctrl = 4'b0100; check(32'hFF00FF00);
        a = 5;            b = 6;            ctrl = 4'b1111; check(0);            // undefined code -> 0
        // random
        for (i = 0; i < 1000; i = i + 1) begin
            a = $random; b = $random;
            ctrl = 4'b0010; check(a + b);
            ctrl = 4'b0110; check(a - b);
            ctrl = 4'b0000; check(a & b);
            ctrl = 4'b0001; check(a | b);
            ctrl = 4'b0100; check(a ^ b);
        end
        if (errors == 0) $display("RESULT: PASS tb_alu (5007 checks)");
        else             $display("RESULT: FAIL tb_alu (%0d errors)", errors);
        $finish;
    end
endmodule
