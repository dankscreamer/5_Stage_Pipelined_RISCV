module branch_unit (
    input  wire       branch,
    input  wire [2:0] funct3,
    input  wire       zero,
    output reg        pc_src
);

    always @(*) begin
        pc_src = 1'b0;

        if (branch == 1'b1) begin
            if (funct3 == 3'b000) begin
                if (zero == 1'b1) begin
                    pc_src = 1'b1;
                end
                else begin
                    pc_src = 1'b0;
                end
            end
            else if (funct3 == 3'b001) begin
                if (zero == 1'b0) begin
                    pc_src = 1'b1;
                end
                else begin
                    pc_src = 1'b0;
                end
            end
            else begin
                pc_src = 1'b0;
            end
        end
        else begin
            pc_src = 1'b0;
        end
    end

endmodule