module alu_control (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [3:0] control_alu
);

    always @(*) begin
        control_alu = 4'b0010;

        if (alu_op == 2'b00) begin
            control_alu = 4'b0010;
        end
        else if (alu_op == 2'b01) begin
            control_alu = 4'b0110;
        end
        else if (alu_op == 2'b10) begin
            if (funct3 == 3'b000) begin
                if (funct7[5] == 1'b1) begin
                    control_alu = 4'b0110;
                end
                else begin
                    control_alu = 4'b0010;
                end
            end
            else if (funct3 == 3'b111) begin
                control_alu = 4'b0000;
            end
            else if (funct3 == 3'b110) begin
                control_alu = 4'b0001;
            end
            else if (funct3 == 3'b100) begin
                control_alu = 4'b0100;
            end
            else begin
                control_alu = 4'b0010;
            end
        end
        else begin
            control_alu = 4'b0010;
        end
    end

endmodule