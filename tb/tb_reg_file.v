`timescale 1ns/1ps
module tb_reg_file;
    reg         clk = 0;
    reg         we;
    reg  [4:0]  rs1, rs2, rd;
    reg  [31:0] wd;
    wire [31:0] r1, r2, b1, b2;
    integer errors = 0, checks = 0, i;

    always #5 clk = ~clk;

    reg_file #(.BYPASS(0)) plain  (.clk(clk), .write_enable(we), .rs1(rs1), .rs2(rs2), .rd(rd),
                                   .write_data(wd), .read_data1(r1), .read_data2(r2));
    reg_file #(.BYPASS(1)) bypass (.clk(clk), .write_enable(we), .rs1(rs1), .rs2(rs2), .rd(rd),
                                   .write_data(wd), .read_data1(b1), .read_data2(b2));

    task expect(input [31:0] got, input [31:0] exp, input [8*24-1:0] what);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                $display("FAIL %0s: got %h expected %h", what, got, exp);
                errors = errors + 1;
            end
        end
    endtask

    task write(input [4:0] r, input [31:0] v);
        begin
            @(negedge clk); we = 1; rd = r; wd = v;
            @(negedge clk); we = 0;
        end
    endtask

    initial begin
        we = 0; rs1 = 0; rs2 = 0; rd = 0; wd = 0;
        // all registers start at zero
        for (i = 0; i < 32; i = i + 1) begin
            rs1 = i; #1; expect(r1, 0, "reset value");
        end
        // write every register, read back on both ports
        for (i = 1; i < 32; i = i + 1) write(i, 32'hA5000000 + i);
        for (i = 1; i < 32; i = i + 1) begin
            rs1 = i; rs2 = 32 - i; #1;
            expect(r1, 32'hA5000000 + i, "port1 readback");
            expect(r2, 32'hA5000000 + (32 - i), "port2 readback");
        end
        // x0 is hard-wired to zero
        write(0, 32'hDEADBEEF);
        rs1 = 0; rs2 = 0; #1;
        expect(r1, 0, "x0 port1"); expect(r2, 0, "x0 port2");
        // write_enable low must not write
        @(negedge clk); we = 0; rd = 5; wd = 32'h12345678;
        @(negedge clk); rs1 = 5; #1; expect(r1, 32'hA5000005, "we=0 no write");
        // same-cycle write + read: plain shows old value, bypass shows new value
        @(negedge clk); we = 1; rd = 7; wd = 32'hCAFEF00D; rs1 = 7; rs2 = 7; #1;
        expect(r1, 32'hA5000007, "plain same-cycle");
        expect(b1, 32'hCAFEF00D, "bypass same-cycle p1");
        expect(b2, 32'hCAFEF00D, "bypass same-cycle p2");
        // bypass must not forward a write to x0
        rd = 0; rs1 = 0; #1; expect(b1, 0, "bypass x0");
        rd = 7; #1;
        @(negedge clk); we = 0; rs1 = 7; #1;
        expect(r1, 32'hCAFEF00D, "plain after write");
        if (errors == 0) $display("RESULT: PASS tb_reg_file (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_reg_file (%0d errors)", errors);
        $finish;
    end
endmodule
