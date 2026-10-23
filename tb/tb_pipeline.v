`timescale 1ns/1ps
// Runs one program on pipeline_top and compares the final register file and data memory
// with the reference model's .expected file (from tools/rvasm.py). Also measures CPI.
//   vvp sim +prog=build/x.hex +expected=build/x.expected [+vcd=build/x.vcd] [+trace]
//           [+pipe=build/x.pipe]   per-cycle stage occupancy for tools/figures.py
// Compile with -Ptb_pipeline.FORWARDING=0 for the no-forwarding variant and
// -Ptb_pipeline.BRANCH_PRED=1|2 for static / dynamic branch prediction.
//
// Cycle counting: cycle 1 is the cycle in which the first instruction is fetched. An
// instruction retires in the cycle it is in WB. "cycles" is the cycle in which the last
// real instruction (before halt) retires, so N independent instructions take N + 4 cycles.
module tb_pipeline;
    parameter FORWARDING  = 1;
    parameter BRANCH_PRED = 0;

    localparam HALT = 32'h00000063;
    localparam MAX_CYCLES = 100000;

    reg clk = 0, reset = 1;
    wire [31:0] pc, instr;
    reg  [31:0] expected [0:287]; // 32 registers + 256 memory words
    reg  [8*256-1:0] prog_file, exp_file, vcd_file;
    integer cycle = 0, retired = 0, last_retire = 0, stalls = 0, flushes = 0, errors = 0, i;
    integer branches = 0, id_redirects = 0;
    reg done = 0, trace = 0;

    // Shadow tracking for pipeline diagrams: every fetched instruction gets a sequence
    // number (0 = bubble), moved between stages using the DUT's own stall/flush signals.
    // The tracked PCs are checked against the DUT's pipeline registers every cycle.
    reg  [8*256-1:0] pipe_file;
    integer pipe_fd = 0, next_seq = 1, s_if = 1, s_id = 0, s_ex = 0, s_mem = 0, s_wb = 0;
    reg  [31:0] seq_pc [0:MAX_CYCLES];

    always #5 clk = ~clk;

    pipeline_top #(.FORWARDING(FORWARDING), .BRANCH_PRED(BRANCH_PRED)) dut (
        .clk(clk), .reset(reset),
        .imem_we(1'b0), .imem_waddr(32'b0), .imem_wdata(32'b0), .pc_current(pc), .instruction(instr)
    );

    // print the PC held by a stage, or "  --  " for a bubble
    task show(input valid, input [31:0] stage_pc);
        begin
            if (valid) $write(" %6h", stage_pc[23:0]);
            else       $write("     --");
        end
    endtask

    initial begin
        if (!$value$plusargs("prog=%s", prog_file) || !$value$plusargs("expected=%s", exp_file)) begin
            $display("RESULT: FAIL usage: +prog=<hex> +expected=<expected>");
            $finish;
        end
        $readmemh(prog_file, dut.imem.memory);
        $readmemh(exp_file, expected);
        trace = $test$plusargs("trace");
        if ($value$plusargs("vcd=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tb_pipeline);
        end
        if (trace)
            $display("cycle      IF     ID     EX    MEM     WB  event");
        if ($value$plusargs("pipe=%s", pipe_file)) begin
            pipe_fd = $fopen(pipe_file, "w");
            $fdisplay(pipe_fd, "# cycle if id ex mem wb stall ex_redirect fwd_a fwd_b id_redirect  (sequence numbers, 0 = bubble)");
        end
        seq_pc[1] = 32'b0;

        @(negedge clk); reset = 0;
        while (!done && cycle < MAX_CYCLES) begin
            cycle = cycle + 1;
            if (trace) begin
                $write("%5d", cycle);
                show(1'b1, dut.pc_current);
                show(dut.id_valid,  dut.id_pc);
                show(dut.ex_valid,  dut.ex_pc);
                show(dut.mem_valid, dut.mem_pc);
                show(dut.wb_valid,  dut.wb_pc);
                if (dut.ex_redirect)      $write("  mispredict -> flush IF/ID, ID/EX");
                else if (dut.id_redirect) $write("  predicted taken in ID -> flush IF/ID");
                else if (dut.stall)       $write("  stall (hazard on ID instruction)");
                if (dut.ex_valid && (dut.forward_a != 0 || dut.forward_b != 0))
                    $write("  fwd A=%b B=%b", dut.forward_a, dut.forward_b);
                $write("\n");
            end
            if (pipe_fd) begin
                if ((dut.id_valid  !== (s_id  != 0)) || (s_id  != 0 && dut.id_pc  !== seq_pc[s_id])  ||
                    (dut.ex_valid  !== (s_ex  != 0)) || (s_ex  != 0 && dut.ex_pc  !== seq_pc[s_ex])  ||
                    (dut.mem_valid !== (s_mem != 0)) || (s_mem != 0 && dut.mem_pc !== seq_pc[s_mem]) ||
                    (dut.wb_valid  !== (s_wb  != 0)) || (s_wb  != 0 && dut.wb_pc  !== seq_pc[s_wb])) begin
                    $display("FAIL: pipeline tracking mismatch at cycle %0d", cycle);
                    errors = errors + 1;
                end
                $fdisplay(pipe_fd, "%0d %0d:%0h %0d %0d %0d %0d %0d %0d %0d %0d %0d", cycle, s_if, seq_pc[s_if],
                          s_id, s_ex, s_mem, s_wb, dut.stall, dut.ex_redirect, dut.forward_a, dut.forward_b,
                          dut.id_redirect);
                // advance the shadow pipeline exactly as the DUT will at the next clock edge
                s_wb  = s_mem;
                s_mem = s_ex;
                s_ex  = dut.id_ex_flush ? 0 : s_id;
                s_id  = dut.if_id_flush ? 0 : (dut.if_id_enable ? s_if : s_id);
                if (dut.pc_enable) begin
                    next_seq = next_seq + 1;
                    s_if = next_seq;
                    seq_pc[s_if] = dut.pc_next;
                end
            end
            // the halt (a branch to itself) is not counted as a branch
            if (dut.ex_branch && dut.ex_instr !== HALT) branches = branches + 1;
            if (dut.ex_redirect) begin
                if (dut.ex_instr !== HALT) flushes = flushes + 1;
            end
            else if (dut.id_redirect)  id_redirects = id_redirects + 1;
            else if (dut.stall)        stalls  = stalls + 1;
            if (dut.wb_valid) begin
                if (dut.wb_instr === HALT) begin
                    done = 1;
                end
                else begin
                    retired     = retired + 1;
                    last_retire = cycle;
                end
            end
            @(negedge clk);
        end

        if (pipe_fd) $fclose(pipe_fd);
        if (!done) begin
            $display("FAIL: timeout, halt never reached WB (pc=%h)", pc);
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
        // branch_flushes = 2-cycle redirects from EX (taken branches when BRANCH_PRED = 0,
        // mispredictions otherwise); id_redirects = 1-cycle static-prediction redirects
        $display("  PERF forwarding=%0d cycles=%0d instructions=%0d stall_cycles=%0d branch_flushes=%0d CPI=%0.3f IPC=%0.3f branch_pred=%0d branches=%0d id_redirects=%0d",
                 FORWARDING, last_retire, retired, stalls, flushes,
                 1.0 * last_retire / retired, 1.0 * retired / last_retire, BRANCH_PRED, branches, id_redirects);
        if (errors == 0) $display("RESULT: PASS tb_pipeline(fwd=%0d,bp=%0d) %0s", FORWARDING, BRANCH_PRED, prog_file);
        else             $display("RESULT: FAIL tb_pipeline(fwd=%0d,bp=%0d) %0s (%0d errors)", FORWARDING, BRANCH_PRED, prog_file, errors);
        $finish;
    end
endmodule
