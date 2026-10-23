`timescale 1ns/1ps
// Runs one program on single_cycle_top and compares the final register file and data
// memory with the reference model's .expected file (from tools/rvasm.py).
//   vvp sim +prog=build/x.hex +expected=build/x.expected [+vcd=build/x.vcd]
module tb_single_cycle;
    reg clk = 0, reset = 1;
    wire [31:0] pc, instr;
    reg  [31:0] expected [0:287]; // 32 registers + 256 memory words
    reg  [8*256-1:0] prog_file, exp_file, vcd_file;
    integer cycles = 0, errors = 0, i;

    localparam HALT = 32'h00000063;
    localparam MAX_CYCLES = 100000;

    always #5 clk = ~clk;

    single_cycle_top dut (.clk(clk), .reset(reset),
        .imem_we(1'b0), .imem_waddr(32'b0), .imem_wdata(32'b0), .pc_current(pc), .instruction(instr));

    initial begin
        if (!$value$plusargs("prog=%s", prog_file) || !$value$plusargs("expected=%s", exp_file)) begin
            $display("RESULT: FAIL usage: +prog=<hex> +expected=<expected>");
            $finish;
        end
        $readmemh(prog_file, dut.imem.memory);
        $readmemh(exp_file, expected);
        if ($value$plusargs("vcd=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tb_single_cycle);
        end

        @(negedge clk); reset = 0;
        // every cycle retires exactly one instruction; stop when halt is fetched
        while (instr !== HALT && cycles < MAX_CYCLES) begin
            @(negedge clk);
            cycles = cycles + 1;
        end

        if (cycles >= MAX_CYCLES) begin
            $display("FAIL: timeout, halt never reached (pc=%h)", pc);
            errors = errors + 1;
        end
        for (i = 0; i < 32; i = i + 1) begin
            if (dut.rf.register[i] !== expected[i]) begin
                $display("FAIL x%0d = %h, expected %h", i, dut.rf.register[i], expected[i]);
                errors = errors + 1;
            end
        end
        for (i = 0; i < 256; i = i + 1) begin
            if (dut.dmem.memory[i] !== expected[32 + i]) begin
                $display("FAIL mem[0x%0h] = %h, expected %h", 4 * i, dut.dmem.memory[i], expected[32 + i]);
                errors = errors + 1;
            end
        end
        $display("  cycles=%0d instructions=%0d CPI=1.00", cycles, cycles);
        if (errors == 0) $display("RESULT: PASS tb_single_cycle %0s", prog_file);
        else             $display("RESULT: FAIL tb_single_cycle %0s (%0d errors)", prog_file, errors);
        $finish;
    end
endmodule
