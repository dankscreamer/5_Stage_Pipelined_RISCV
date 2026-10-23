`timescale 1ns/1ps
module tb_forwarding_unit;
    reg  [4:0] rs1, rs2, ex_mem_rd, mem_wb_rd;
    reg        ex_mem_we, mem_wb_we;
    wire [1:0] fa, fb, na, nb;
    integer errors = 0, checks = 0;

    forwarding_unit #(.ENABLE(1)) dut (.id_ex_rs1(rs1), .id_ex_rs2(rs2),
        .ex_mem_reg_write(ex_mem_we), .ex_mem_rd(ex_mem_rd),
        .mem_wb_reg_write(mem_wb_we), .mem_wb_rd(mem_wb_rd), .forward_a(fa), .forward_b(fb));
    forwarding_unit #(.ENABLE(0)) off (.id_ex_rs1(rs1), .id_ex_rs2(rs2),
        .ex_mem_reg_write(ex_mem_we), .ex_mem_rd(ex_mem_rd),
        .mem_wb_reg_write(mem_wb_we), .mem_wb_rd(mem_wb_rd), .forward_a(na), .forward_b(nb));

    task check(input [4:0] r1, input [4:0] r2, input we1, input [4:0] d1, input we2, input [4:0] d2,
               input [1:0] exp_a, input [1:0] exp_b, input [8*32-1:0] what);
        begin
            rs1 = r1; rs2 = r2; ex_mem_we = we1; ex_mem_rd = d1; mem_wb_we = we2; mem_wb_rd = d2; #1;
            checks = checks + 1;
            if (fa !== exp_a || fb !== exp_b || na !== 2'b00 || nb !== 2'b00) begin
                $display("FAIL %0s: A=%b B=%b (expected %b %b), disabled A=%b B=%b", what, fa, fb, exp_a, exp_b, na, nb);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        //     rs1 rs2  we rd   we rd   A      B
        check(1, 2,  0, 0,   0, 0,   2'b00, 2'b00, "no writers");
        check(1, 2,  1, 1,   0, 0,   2'b10, 2'b00, "EX/MEM -> A");
        check(1, 2,  1, 2,   0, 0,   2'b00, 2'b10, "EX/MEM -> B");
        check(1, 2,  0, 0,   1, 1,   2'b01, 2'b00, "MEM/WB -> A");
        check(1, 2,  0, 0,   1, 2,   2'b00, 2'b01, "MEM/WB -> B");
        check(3, 3,  1, 3,   1, 3,   2'b10, 2'b10, "EX/MEM wins over MEM/WB");
        check(3, 4,  1, 4,   1, 3,   2'b01, 2'b10, "mixed sources");
        check(0, 0,  1, 0,   1, 0,   2'b00, 2'b00, "x0 never forwarded");
        check(5, 5,  0, 5,   0, 5,   2'b00, 2'b00, "reg_write low");
        if (errors == 0) $display("RESULT: PASS tb_forwarding_unit (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_forwarding_unit (%0d errors)", errors);
        $finish;
    end
endmodule
