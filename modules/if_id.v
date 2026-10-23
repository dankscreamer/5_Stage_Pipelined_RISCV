// IF/ID pipeline register.
//   enable = 0 : hold (load-use / RAW stall)
//   flush  = 1 : insert a bubble (taken branch). flush has priority over enable.
module if_id (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire        flush,
    input  wire [31:0] pc_in,
    input  wire [31:0] instr_in,

    output reg         valid_out,
    output reg  [31:0] pc_out,
    output reg  [31:0] instr_out
);

    always @(posedge clk) begin
        if (reset || flush) begin
            valid_out <= 1'b0;
            pc_out    <= 32'b0;
            instr_out <= 32'h00000013; // NOP
        end
        else if (enable) begin
            valid_out <= 1'b1;
            pc_out    <= pc_in;
            instr_out <= instr_in;
        end
    end

endmodule
