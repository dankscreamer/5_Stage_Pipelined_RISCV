// Program counter. enable = 0 holds the current PC (used for pipeline stalls).
module pc (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire [31:0] next_pc,
    output reg  [31:0] pc_out
);

    always @(posedge clk) begin
        if (reset) begin
            pc_out <= 32'b0;
        end
        else if (enable) begin
            pc_out <= next_pc;
        end
    end

endmodule
