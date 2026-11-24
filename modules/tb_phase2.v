`timescale 1ns / 1ps

`ifdef PIPELINED
`include "modules/riscv_pipeline.v"
`define REGFILE uut.u_reg_file
`else
`include "modules/riscv_single_cycle.v"
`define REGFILE uut.u_id_stage.u_reg_file
`endif

// Shared verification harness: compile once for each architecture.
module tb_phase2;
    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycles = 0;
    integer i, stop_pc, max_cycles;
    reg [1023:0] wave_file;

`ifdef PIPELINED
    riscv_pipeline uut (.clk(clk), .rst(rst));
    wire retire_valid = uut.mem_wb_valid;
    wire [31:0] retire_pc = uut.mem_wb_pc;
`else
    riscv_single_cycle uut (.clk(clk), .rst(rst));
    wire retire_valid = 1'b1;
    wire [31:0] retire_pc = uut.p_out;
`endif

    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("STOP_PC=%d", stop_pc))
            $fatal(1, "STOP_PC is required");
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
            max_cycles = 150;
        if ($value$plusargs("VCD=%s", wave_file)) begin
            $dumpfile(wave_file);
            $dumpvars(0, tb_phase2);
        end

        // Deterministic TEST FIXTURE, not a hardware register/RAM reset.
        #1;
        for (i = 0; i < 32; i = i + 1)
            `REGFILE.register[i] = 32'b0;
        for (i = 0; i < 64; i = i + 1)
            uut.u_mem_stage.u_data_mem.memory[i] = 32'b0;

        repeat (3) @(negedge clk);
        rst = 1'b0;
    end

    always @(posedge clk) begin
        if (rst) begin
            if (`REGFILE.write_enable !== 1'b0 ||
                uut.u_mem_stage.u_data_mem.mem_write !== 1'b0)
                $fatal(1, "A state write was enabled during reset");
            #1;
            if (uut.p_out !== 32'b0)
                $fatal(1, "PC did not reset synchronously");
            for (i = 0; i < 32; i = i + 1)
                if (`REGFILE.register[i] !== 32'b0)
                    $fatal(1, "Register changed during reset");
            for (i = 0; i < 64; i = i + 1)
                if (uut.u_mem_stage.u_data_mem.memory[i] !== 32'b0)
                    $fatal(1, "Memory changed during reset");
        end else begin
            cycles = cycles + 1;
            if (retire_valid) begin
                $display("RETIRE %0d %08x", cycles, retire_pc);
                if (retire_pc == stop_pc) begin
                    // Observe the register write after nonblocking updates.
                    #1;
                    $display("CYCLES %0d", cycles);
                    for (i = 0; i < 32; i = i + 1)
                        $display("REG %0d %08x", i, `REGFILE.register[i]);
                    for (i = 0; i < 64; i = i + 1)
                        $display("MEM %0d %08x", i,
                                 uut.u_mem_stage.u_data_mem.memory[i]);
                    if (`REGFILE.read_data1 === 32'bx)
                        $fatal(1, "Unknown register read at completion");
                    $finish;
                end
            end
            if (cycles >= max_cycles)
                $fatal(1, "Timeout before the final instruction retired");
        end
    end
endmodule

`undef REGFILE
