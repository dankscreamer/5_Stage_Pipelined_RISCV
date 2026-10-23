// Stall and flush control.
//
// Data hazards (instruction in ID reads a register that an older instruction will write):
//   FORWARDING = 1 : only a load in EX needs a stall (its data exists after MEM).
//   FORWARDING = 0 : any writer in EX or MEM needs a stall. A writer in WB is covered by
//                    the register file's write-through bypass.
// Control hazards: branches resolve in EX.
//   ex_redirect (the prediction for the branch in EX was wrong) flushes the two younger
//   instructions in IF/ID and ID/EX (2-cycle penalty).
//   id_redirect (static prediction: a branch in ID predicted taken) flushes only the one
//   instruction in IF/ID (1-cycle penalty).
module hazard_unit #(
    parameter FORWARDING = 1
) (
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input  wire       id_uses_rs1,
    input  wire       id_uses_rs2,

    input  wire       id_ex_reg_write,
    input  wire       id_ex_mem_read,
    input  wire [4:0] id_ex_rd,
    input  wire       ex_mem_reg_write,
    input  wire [4:0] ex_mem_rd,

    input  wire       ex_redirect,
    input  wire       id_redirect,

    output wire       stall,
    output wire       pc_enable,
    output wire       if_id_enable,
    output wire       if_id_flush,
    output wire       id_ex_flush
);

    wire dep_ex  = (id_ex_rd != 5'b0) &&
                   ((id_uses_rs1 && (id_ex_rd == id_rs1)) || (id_uses_rs2 && (id_ex_rd == id_rs2)));
    wire dep_mem = (ex_mem_rd != 5'b0) &&
                   ((id_uses_rs1 && (ex_mem_rd == id_rs1)) || (id_uses_rs2 && (ex_mem_rd == id_rs2)));

    wire load_use  = id_ex_mem_read && dep_ex;
    wire raw_stall = (id_ex_reg_write && dep_ex) || (ex_mem_reg_write && dep_mem);

    assign stall = FORWARDING ? load_use : raw_stall;

    // An EX redirect overrides a stall: the stalled instruction is on the wrong path anyway.
    // (id_redirect is only raised when there is no stall.)
    assign pc_enable    = ~stall | ex_redirect;
    assign if_id_enable = ~stall;
    assign if_id_flush  = ex_redirect | id_redirect;
    assign id_ex_flush  = ex_redirect | stall;

endmodule
