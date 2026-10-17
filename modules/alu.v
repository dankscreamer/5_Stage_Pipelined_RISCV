module ALU_RISCV (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  control_alu,

    output reg  [31:0] result_alu,
    output wire        zero
);

    always @(*) begin
        if (control_alu == 4'b0000) begin
            result_alu = a & b;
        end
        else if (control_alu == 4'b0001) begin
            result_alu = a | b;
        end
        else if (control_alu == 4'b0010) begin
            result_alu = a + b;
        end
        else if (control_alu == 4'b0110) begin
            result_alu = a - b;
        end
        else if (control_alu == 4'b0100) begin
            result_alu = a ^ b;
        end
        else begin
            result_alu = 32'b0;
        end
    end

    assign zero = (result_alu == 32'b0) ? 1'b1 : 1'b0;

endmodule