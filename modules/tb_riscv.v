`timescale 1ns / 1ps

`include "modules/riscv_single_cycle.v"

module tb_riscv;

    reg clk;
    reg rst;

    // Instantiate the top-level single-cycle RISC-V processor
    riscv_single_cycle uut (
        .clk (clk),
        .rst (rst)
    );

    // Generate a clock with a 10ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Open the VCD waveform file for GTKWave or Vivado
        $dumpfile("riscv_single_cycle.vcd");
        $dumpvars(0, tb_riscv);

        // Initialize signals
        clk = 1'b0;
        rst = 1'b1;
        
        // Hold reset active for 15ns
        #15;
        rst = 1'b0;

        // Run the simulation long enough for instructions in program.hex to execute
        #120;
        
        $finish;
    end

endmodule