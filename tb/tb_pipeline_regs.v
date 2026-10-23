`timescale 1ns/1ps
// Stall / flush behaviour of the pipeline registers.
module tb_pipeline_regs;
    reg         clk = 0, reset = 1, enable = 1, flush = 0;
    reg  [31:0] pc_in = 0, instr_in = 0;
    wire        valid, ex_valid, ex_rw, ex_mw, ex_br, pred, ex_pred;
    wire [31:0] pc_out, instr_out;
    integer errors = 0, checks = 0;

    always #5 clk = ~clk;

    if_id u_if_id (.clk(clk), .reset(reset), .enable(enable), .flush(flush),
                   .pc_in(pc_in), .instr_in(instr_in), .pred_in(1'b1),
                   .valid_out(valid), .pc_out(pc_out), .instr_out(instr_out), .pred_out(pred));

    id_ex u_id_ex (.clk(clk), .reset(reset), .flush(flush),
        .valid_in(1'b1), .pc_in(pc_in), .instr_in(instr_in),
        .reg_write_in(1'b1), .alu_src_in(1'b1), .mem_write_in(1'b1), .result_src_in(1'b1),
        .branch_in(1'b1), .pred_taken_in(1'b1), .alu_op_in(2'b11), .read_data1_in(32'h1), .read_data2_in(32'h2),
        .imm_in(32'h3), .rs1_in(5'd1), .rs2_in(5'd2), .rd_in(5'd3),
        .valid_out(ex_valid), .pc_out(), .instr_out(), .reg_write_out(ex_rw), .alu_src_out(),
        .mem_write_out(ex_mw), .result_src_out(), .branch_out(ex_br), .pred_taken_out(ex_pred), .alu_op_out(),
        .read_data1_out(), .read_data2_out(), .imm_out(), .rs1_out(), .rs2_out(), .rd_out());

    task expect(input cond, input [8*32-1:0] what);
        begin
            checks = checks + 1;
            if (!cond) begin
                $display("FAIL %0s (valid=%b pc=%h instr=%h ex_valid=%b)", what, valid, pc_out, instr_out, ex_valid);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        @(negedge clk);
        expect(!valid && instr_out == 32'h13 && !ex_valid, "reset gives bubbles");
        reset = 0; pc_in = 32'h10; instr_in = 32'hAAAA0033;
        @(negedge clk);
        expect(valid && pc_out == 32'h10 && instr_out == 32'hAAAA0033 && pred, "IF/ID loads");
        expect(ex_valid && ex_rw && ex_mw && ex_br, "ID/EX loads");
        enable = 0; pc_in = 32'h14; instr_in = 32'hBBBB0033;
        @(negedge clk);
        expect(valid && pc_out == 32'h10, "IF/ID holds on stall");
        flush = 1;
        @(negedge clk);
        expect(!valid && instr_out == 32'h13 && !pred, "flush beats stall");
        expect(!ex_valid && !ex_rw && !ex_mw && !ex_br && !ex_pred, "ID/EX flush clears control");
        flush = 0; enable = 1;
        @(negedge clk);
        expect(valid && pc_out == 32'h14, "resumes after flush");
        if (errors == 0) $display("RESULT: PASS tb_pipeline_regs (%0d checks)", checks);
        else             $display("RESULT: FAIL tb_pipeline_regs (%0d errors)", errors);
        $finish;
    end
endmodule
