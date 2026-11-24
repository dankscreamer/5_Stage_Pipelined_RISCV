module pc (
    input wire clk,
    input wire rst,
    input wire [31:0] p_nxt,
    output reg [31:0] p_out
);
    always @(posedge clk) begin
        if (rst)
            p_out <= 32'b0;
        else
            p_out <= p_nxt;
    end
endmodule
