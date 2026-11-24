`timescale 1ns / 1ps

`include "modules/riscv_single_cycle.v"

module tb_riscv;

    reg clk;
    reg rst;
    reg [1023:0] wave_file;

    // Instantiate the top-level single-cycle RISC-V processor
    riscv_single_cycle uut (
        .clk (clk),
        .rst (rst)
    );

    // Generate a clock with a 10ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Open the VCD waveform file for GTKWave or Vivado
        if (!$value$plusargs("VCD=%s", wave_file))
            wave_file = "riscv_single_cycle.vcd";
        $dumpfile(wave_file);
        $dumpvars(0, tb_riscv);

        // Initialize signals
        clk = 1'b0;
        rst = 1'b1;
        
        // Release reset on a falling edge, away from the PC sampling edge.
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // Run the simulation long enough for instructions in program.hex to execute
        #120;
        
        $finish;
    end

endmodule
