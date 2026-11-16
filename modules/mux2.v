module mux2 (
    input  wire [31:0] in0,
    input  wire [31:0] in1,
    input  wire        sel,
    output reg  [31:0] out
);

    always @(*) begin
        if (sel == 1'b0) begin
            out = in0;
        end
        else begin
            out = in1;
        end
    end

endmodule