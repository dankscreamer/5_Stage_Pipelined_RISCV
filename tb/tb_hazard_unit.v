`timescale 1ns/1ps
module tb_hazard_unit;
    reg  [4:0] rs1, rs2, ex_rd, mem_rd;
    reg        u1, u2, ex_we, ex_load, mem_we, taken, idr;
    wire       s1, pe1, ie1, if1, xf1;   // FORWARDING = 1
    wire       s0, pe0, ie0, if0, xf0;   // FORWARDING = 0
    integer errors = 0, checks = 0;

    hazard_unit #(.FORWARDING(1)) fwd (.id_rs1(rs1), .id_rs2(rs2), .id_uses_rs1(u1), .id_uses_rs2(u2),
        .id_ex_reg_write(ex_we), .id_ex_mem_read(ex_load), .id_ex_rd(ex_rd),
        .ex_mem_reg_write(mem_we), .ex_mem_rd(mem_rd), .ex_redirect(taken), .id_redirect(idr),
        .stall(s1), .pc_enable(pe1), .if_id_enable(ie1), .if_id_flush(if1), .id_ex_flush(xf1));
    hazard_unit #(.FORWARDING(0)) nofwd (.id_rs1(rs1), .id_rs2(rs2), .id_uses_rs1(u1), .id_uses_rs2(u2),
        .id_ex_reg_write(ex_we), .id_ex_mem_read(ex_load), .id_ex_rd(ex_rd),
        .ex_mem_reg_write(mem_we), .ex_mem_rd(mem_rd), .ex_redirect(taken), .id_redirect(idr),
        .stall(s0), .pc_enable(pe0), .if_id_enable(ie0), .if_id_flush(if0), .id_ex_flush(xf0));

    // expected = {stall, pc_enable, if_id_enable, if_id_flush, id_ex_flush} for each variant
    task check(input [4:0] r1, input [4:0] r2, input a1, input a2,
               input exw, input exl, input [4:0] exd, input mw, input [4:0] md, input tk,
               input [4:0] exp1, input [4:0] exp0, input [8*40-1:0] what);
        begin
            rs1 = r1; rs2 = r2; u1 = a1; u2 = a2; ex_we = exw; ex_load = exl; ex_rd = exd;
            mem_we = mw; mem_rd = md; taken = tk; idr = 0; #1;
            checks = checks + 1;
            if ({s1, pe1, ie1, if1, xf1} !== exp1 || {s0, pe0, ie0, if0, xf0} !== exp0) begin
                $display("FAIL %0s: fwd=%b nofwd=%b (expected %b %b)", what,
                         {s1, pe1, ie1, if1, xf1}, {s0, pe0, ie0, if0, xf0}, exp1, exp0);
                errors = errors + 1;
            end
        end
    endtask

    localparam RUN   = 5'b01100;  // no stall, no flush
    localparam STALL = 5'b10001;  // hold PC + IF/ID, bubble into ID/EX
    localparam FLUSH = 5'b01111;  // taken branch
    localparam FLUSH_OVER_STALL = 5'b11011;

    initial begin
        //     rs1 rs2 u1 u2  exW exL exRd memW memRd taken  fwd=1  fwd=0
        check(1, 2, 1, 1,  0,  0,  0,   0,   0,    0,     RUN,   RUN,   "independent");
        check(1, 2, 1, 1,  1,  0,  1,   0,   0,    0,     RUN,   STALL, "ALU result in EX");
        check(1, 2, 1, 1,  0,  0,  0,   1,   2,    0,     RUN,   STALL, "ALU result in MEM");
        check(1, 2, 1, 1,  1,  1,  2,   0,   0,    0,     STALL, STALL, "load-use on rs2");
        check(1, 2, 1, 1,  1,  1,  1,   0,   0,    0,     STALL, STALL, "load-use on rs1");
        check(1, 2, 1, 0,  1,  1,  2,   0,   0,    0,     RUN,   RUN,   "rs2 field unused (I-type)");
        check(0, 0, 1, 1,  1,  1,  0,   1,   0,    0,     RUN,   RUN,   "x0 never a hazard");
        check(1, 2, 1, 1,  0,  0,  0,   0,   0,    1,     FLUSH, FLUSH, "EX redirect");
        check(1, 2, 1, 1,  0,  0,  0,   1,   1,    1,     FLUSH, FLUSH_OVER_STALL, "EX redirect overrides stall");
        // static-prediction redirect from ID: flush only IF/ID, PC loads the target
        rs1 = 1; rs2 = 2; u1 = 1; u2 = 1; ex_we = 0; ex_load = 0; ex_rd = 0; mem_we = 0; mem_rd = 0;
        taken = 0; idr = 1; #1; checks = checks + 1;
        if ({s1, pe1, ie1, if1, xf1} !== 5'b01110) begin
            $display("FAIL id redirect: %b", {s1, pe1, ie1, if1, xf1}); errors = errors + 1;
        end
        if (errors == 0) $display("RESULT: PASS tb_hazard_unit (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_hazard_unit (%0d errors)", errors);
        $finish;
    end
endmodule
