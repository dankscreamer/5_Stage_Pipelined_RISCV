module control_unit (
    input  wire [6:0] opcode,
    output reg        reg_write,
    output reg  [1:0] imm_src,
    output reg        alu_src,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,
    output reg        branch,
    output reg  [1:0] alu_op
);

    always @(*) begin
        reg_write  = 1'b0;
        imm_src    = 2'b00;
        alu_src    = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        alu_op     = 2'b00;

        if (opcode == 7'b0110011) begin
            reg_write  = 1'b1;
            imm_src    = 2'b00;
            alu_src    = 1'b0;
            mem_read   = 1'b0;
            mem_write  = 1'b0;
            mem_to_reg = 1'b0;
            branch     = 1'b0;
            alu_op     = 2'b10;
        end
        else if (opcode == 7'b0010011) begin
            reg_write  = 1'b1;
            imm_src    = 2'b00;
            alu_src    = 1'b1;
            mem_read   = 1'b0;
            mem_write  = 1'b0;
            mem_to_reg = 1'b0;
            branch     = 1'b0;
            alu_op     = 2'b10;
        end
        else if (opcode == 7'b0000011) begin
            reg_write  = 1'b1;
            imm_src    = 2'b00;
            alu_src    = 1'b1;
            mem_read   = 1'b1;
            mem_write  = 1'b0;
            mem_to_reg = 1'b1;
            branch     = 1'b0;
            alu_op     = 2'b00;
        end
        else if (opcode == 7'b0100011) begin
            reg_write  = 1'b0;
            imm_src    = 2'b01;
            alu_src    = 1'b1;
            mem_read   = 1'b0;
            mem_write  = 1'b1;
            mem_to_reg = 1'b0;
            branch     = 1'b0;
            alu_op     = 2'b00;
        end
        else if (opcode == 7'b1100011) begin
            reg_write  = 1'b0;
            imm_src    = 2'b10;
            alu_src    = 1'b0;
            mem_read   = 1'b0;
            mem_write  = 1'b0;
            mem_to_reg = 1'b0;
            branch     = 1'b1;
            alu_op     = 2'b01;
        end
        else begin
            reg_write  = 1'b0;
            imm_src    = 2'b00;
            alu_src    = 1'b0;
            mem_read   = 1'b0;
            mem_write  = 1'b0;
            mem_to_reg = 1'b0;
            branch     = 1'b0;
            alu_op     = 2'b00;
        end
    end

 endmodule