// IF/ID pipeline register.
//   enable = 0 : hold (load-use / RAW stall)
//   flush  = 1 : insert a bubble (taken branch / misprediction). flush has priority over enable.
// pred_* carries the IF-stage branch prediction (taken or not) along with the instruction.
module if_id (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire        flush,
    input  wire [31:0] pc_in,
    input  wire [31:0] instr_in,
    input  wire        pred_in,

    output reg         valid_out,
    output reg  [31:0] pc_out,
    output reg  [31:0] instr_out,
    output reg         pred_out
);

    always @(posedge clk) begin
        if (reset || flush) begin
            valid_out <= 1'b0;
            pc_out    <= 32'b0;
            instr_out <= 32'h00000013; // NOP
            pred_out  <= 1'b0;
        end
        else if (enable) begin
            valid_out <= 1'b1;
            pc_out    <= pc_in;
            instr_out <= instr_in;
            pred_out  <= pred_in;
        end
    end

endmodule
