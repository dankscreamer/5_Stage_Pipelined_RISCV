`timescale 1ns/1ps
module tb_data_mem;
    reg         clk = 0;
    reg         we;
    reg  [31:0] addr, wd;
    wire [31:0] rd;
    integer errors = 0, checks = 0, i;

    always #5 clk = ~clk;

    data_mem dut (.clk(clk), .mem_write(we), .address(addr), .write_data(wd), .read_data(rd));

    task expect(input [31:0] exp);
        begin
            #1; checks = checks + 1;
            if (rd !== exp) begin
                $display("FAIL addr=%h read %h expected %h", addr, rd, exp);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        we = 0; addr = 0; wd = 0;
        for (i = 0; i < 256; i = i + 1) begin addr = 4 * i; expect(0); end
        for (i = 0; i < 256; i = i + 1) begin
            @(negedge clk); we = 1; addr = 4 * i; wd = ~i;
        end
        @(negedge clk); we = 0;
        for (i = 0; i < 256; i = i + 1) begin addr = 4 * i; expect(~i); end
        // write is synchronous: data not visible before the clock edge
        @(negedge clk); addr = 8; wd = 32'h55AA55AA; we = 1; expect(~2);
        @(negedge clk); we = 0; expect(32'h55AA55AA);
        // byte offset bits are ignored (word aligned)
        addr = 11; expect(32'h55AA55AA);
        if (errors == 0) $display("RESULT: PASS tb_data_mem (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_data_mem (%0d errors)", errors);
        $finish;
    end
endmodule
