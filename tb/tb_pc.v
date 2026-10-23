`timescale 1ns/1ps
module tb_pc;
    reg         clk = 0, reset, enable;
    reg  [31:0] next_pc;
    wire [31:0] pc_out;
    integer errors = 0, checks = 0;

    always #5 clk = ~clk;

    pc dut (.clk(clk), .reset(reset), .enable(enable), .next_pc(next_pc), .pc_out(pc_out));

    task expect(input [31:0] exp);
        begin
            checks = checks + 1;
            if (pc_out !== exp) begin
                $display("FAIL pc=%h expected %h", pc_out, exp);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        reset = 1; enable = 1; next_pc = 32'h40;
        @(negedge clk); expect(0);                       // reset wins over next_pc
        reset = 0;
        @(negedge clk); expect(32'h40);                  // loads next_pc
        next_pc = 32'h44; enable = 0;
        @(negedge clk); expect(32'h40);                  // stall holds
        enable = 1;
        @(negedge clk); expect(32'h44);
        reset = 1;
        @(negedge clk); expect(0);
        if (errors == 0) $display("RESULT: PASS tb_pc (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_pc (%0d errors)", errors);
        $finish;
    end
endmodule
