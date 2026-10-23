`timescale 1ns/1ps
module tb_imm_gen;
    reg  [31:0] instr;
    reg  [1:0]  src;
    wire [31:0] imm;
    integer errors = 0, checks = 0, i;
    wire signed [31:0] sra20 = $signed(instr) >>> 20; // keep the shift in a signed context

    imm_gen dut (.instruction(instr), .src(src), .out(imm));

    task check(input [31:0] word, input [1:0] s, input [31:0] expected);
        begin
            instr = word; src = s; #1;
            checks = checks + 1;
            if (imm !== expected) begin
                $display("FAIL instr=%h src=%b -> %h (expected %h)", word, s, imm, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // Encodings produced by tools/rvasm.py (and 0xffdff06f = the standard "j .-4")
        check(32'h00500093, 2'b00, 32'd5);           // addi x1, x0, 5
        check(32'hFFF00093, 2'b00, 32'hFFFFFFFF);    // addi x1, x0, -1
        check(32'h8000A203, 2'b00, -32'sd2048);      // lw x4, -2048(x1)
        check(32'hFE20AE23, 2'b01, -32'sd4);         // sw x2, -4(x1)
        check(32'h7E532FA3, 2'b01, 32'd2047);        // sw x5, 2047(x6)
        check(32'hFE208CE3, 2'b10, -32'sd8);         // beq x1, x2, -8
        check(32'h7E419FE3, 2'b10, 32'd4094);        // bne x3, x4, 4094
        check(32'h80000063, 2'b10, -32'sd4096);      // beq x0, x0, -4096
        check(32'h002090E3, 2'b10, 32'd2048);        // bne x1, x2, 2048 (imm[11] lives in bit 7)
        check(32'hFFDFF06F, 2'b11, -32'sd4);         // jal x0, -4
        check(32'h0080006F, 2'b11, 32'd8);           // jal x0, 8
        check(32'h0010006F, 2'b11, 32'd2048);        // jal x0, 2048 (imm[11] lives in bit 20)
        // random I and S checked against arithmetic-shift definitions
        for (i = 0; i < 500; i = i + 1) begin
            instr = $random; #1;
            check(instr, 2'b00, sra20);
            check(instr, 2'b01, (sra20 & ~32'h1F) | instr[11:7]);
        end
        if (errors == 0) $display("RESULT: PASS tb_imm_gen (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_imm_gen (%0d errors)", errors);
        $finish;
    end
endmodule
