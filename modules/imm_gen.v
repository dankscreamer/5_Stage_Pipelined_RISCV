module imm_gen (
    input  wire [31:0] instruction,
    input  wire [1:0]  src,
    output reg  [31:0] out
);

    reg [19:0] pad;

    always @(*) begin 
        if (instruction[31] == 1'b0) begin
            pad = 20'b0;
        end
        else begin
            pad = 20'hFFFFF;
        end

        if (src == 2'b00) begin
            out = {pad, instruction[31:20]};
        end
        else if (src == 2'b01) begin
            out = {pad, instruction[31:25], instruction[11:7]};
        end
        else if (src == 2'b10) begin
            out = {pad[18:0], instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        end
        else if (src == 2'b11) begin
            out = {pad[10:0], instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
        end
        else begin
            out = 32'b0;
        end
    end

endmodule 