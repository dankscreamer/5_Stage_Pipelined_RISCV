// Selects the source of each ALU operand in EX.
//   2'b00 : value read from the register file in ID
//   2'b10 : EX/MEM ALU result (instruction one ahead)
//   2'b01 : MEM/WB write-back result (instruction two ahead)
// EX/MEM has priority because it holds the most recent write to the register.
// A load in EX/MEM is never forwarded from: the hazard unit stalls that case.
// ENABLE = 0 disables forwarding (the hazard unit then stalls instead).
module forwarding_unit #(
    parameter ENABLE = 1
) (
    input  wire [4:0] id_ex_rs1,
    input  wire [4:0] id_ex_rs2,
    input  wire       ex_mem_reg_write,
    input  wire [4:0] ex_mem_rd,
    input  wire       mem_wb_reg_write,
    input  wire [4:0] mem_wb_rd,
    output wire [1:0] forward_a,
    output wire [1:0] forward_b
);

    // (continuous assigns rather than always @(*): with ENABLE = 0 the block would have no
    //  sensitivities and never execute in simulation, leaving the outputs at X)
    wire ex_mem_a = ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1);
    wire ex_mem_b = ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2);
    wire mem_wb_a = mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1);
    wire mem_wb_b = mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2);

    assign forward_a = !ENABLE  ? 2'b00 :
                       ex_mem_a ? 2'b10 :
                       mem_wb_a ? 2'b01 : 2'b00;
    assign forward_b = !ENABLE  ? 2'b00 :
                       ex_mem_b ? 2'b10 :
                       mem_wb_b ? 2'b01 : 2'b00;

endmodule
