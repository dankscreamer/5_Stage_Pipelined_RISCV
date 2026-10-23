`timescale 1ns/1ps
module tb_branch_predictor;
    reg         clk = 0, reset = 1, clear = 0, upd = 0, upd_taken = 0;
    reg  [31:0] lookup = 0, upd_pc = 0, upd_target = 0;
    wire        taken;
    wire [31:0] target;
    integer errors = 0, checks = 0;

    always #5 clk = ~clk;

    branch_predictor #(.ENTRIES(8)) dut (.clk(clk), .reset(reset), .clear(clear),
        .lookup_pc(lookup), .pred_taken(taken), .pred_target(target),
        .update_en(upd), .update_pc(upd_pc), .update_taken(upd_taken), .update_target(upd_target));

    task resolve(input [31:0] pc, input t, input [31:0] tgt);
        begin
            @(negedge clk); upd = 1; upd_pc = pc; upd_taken = t; upd_target = tgt;
            @(negedge clk); upd = 0;
        end
    endtask

    task expect(input [31:0] pc, input exp_taken, input [31:0] exp_target, input [8*40-1:0] what);
        begin
            lookup = pc; #1; checks = checks + 1;
            if (taken !== exp_taken || (exp_taken && target !== exp_target)) begin
                $display("FAIL %0s: pc=%h taken=%b target=%h", what, pc, taken, target);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        @(negedge clk); reset = 0;
        expect(32'h40, 0, 0, "empty table predicts not taken");
        resolve(32'h40, 1, 32'h10);
        expect(32'h40, 1, 32'h10, "taken branch allocated (weakly taken)");
        expect(32'h44, 0, 0, "other PC still misses");
        resolve(32'h40, 0, 32'h10);
        expect(32'h40, 0, 0, "one not-taken: 10 -> 01, predict not taken");
        resolve(32'h40, 1, 32'h10);
        resolve(32'h40, 1, 32'h10);
        expect(32'h40, 1, 32'h10, "01 -> 10 -> 11, predict taken");
        resolve(32'h40, 0, 32'h10);
        expect(32'h40, 1, 32'h10, "hysteresis: one not-taken from 11 stays taken");
        resolve(32'h44, 0, 32'h20);
        expect(32'h44, 0, 0, "not-taken miss is not allocated");
        resolve(32'h60, 1, 32'h30);   // same index as 0x40, different tag
        expect(32'h60, 1, 32'h30, "aliasing PC replaces the entry");
        expect(32'h40, 0, 0, "tag check: old PC now misses");
        @(negedge clk); clear = 1; @(negedge clk); clear = 0;
        expect(32'h60, 0, 0, "clear empties the table");
        if (errors == 0) $display("RESULT: PASS tb_branch_predictor (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_branch_predictor (%0d errors)", errors);
        $finish;
    end
endmodule
