`include "include.vh"
`include "include_stage.vh"

// Phase 2: five stages, no forwarding, hazard detection, or data stalls.
// Software must leave three instructions between a writer and its reader.
module riscv_pipeline (
    input wire clk,
    input wire rst
);
    // IF and IF/ID register.
    wire [31:0] p_out, instruction;
    reg if_id_valid;
    reg [31:0] if_id_pc, if_id_instruction;

    // ID combinational outputs.
    wire [31:0] read_data1, read_data2, imm_out;
    wire reg_write, alu_src, mem_read, mem_write, mem_to_reg, branch;
    wire [1:0] imm_src, alu_op;

    // ID/EX register: operands, instruction identity, and controls.
    reg id_ex_valid;
    reg [31:0] id_ex_pc, id_ex_read_data1, id_ex_read_data2, id_ex_imm;
    reg [4:0] id_ex_rd;
    reg [2:0] id_ex_funct3;
    reg [6:0] id_ex_funct7;
    reg [1:0] id_ex_alu_op;
    reg id_ex_reg_write, id_ex_alu_src, id_ex_mem_read;
    reg id_ex_mem_write, id_ex_mem_to_reg, id_ex_branch;

    // EX and EX/MEM register.
    wire [31:0] result_alu, pc_branch;
    wire pc_src;
    reg ex_mem_valid;
    reg [31:0] ex_mem_pc, ex_mem_result, ex_mem_store_data;
    reg [4:0] ex_mem_rd;
    reg ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write, ex_mem_mem_to_reg;

    // MEM and MEM/WB register.
    wire [31:0] read_data;
    reg mem_wb_valid;
    reg [31:0] mem_wb_pc, mem_wb_result, mem_wb_read_data;
    reg [4:0] mem_wb_rd;
    reg mem_wb_reg_write, mem_wb_mem_to_reg;
    wire [31:0] write_data;
    wire wb_write_enable = mem_wb_valid && mem_wb_reg_write && !rst;

    if_stage u_if_stage (
        .clk(clk), .rst(rst), .pc_src(pc_src), .pc_branch(pc_branch),
        .p_out(p_out), .instruction(instruction)
    );

    control_unit u_control_unit (
        .opcode(if_id_instruction[6:0]), .reg_write(reg_write),
        .imm_src(imm_src), .alu_src(alu_src), .mem_read(mem_read),
        .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .branch(branch), .alu_op(alu_op)
    );

    // Read addresses belong to ID; write address/data belong to WB.
    // There is deliberately no same-cycle WB-to-ID bypass.
    reg_file u_reg_file (
        .clk(clk), .write_enable(wb_write_enable),
        .rs1(if_id_instruction[19:15]), .rs2(if_id_instruction[24:20]),
        .rd(mem_wb_rd), .write_data(write_data),
        .read_data1(read_data1), .read_data2(read_data2)
    );

    imm_gen u_imm_gen (
        .instruction(if_id_instruction), .src(imm_src), .out(imm_out)
    );

    ex_stage u_ex_stage (
        .p_out(id_ex_pc), .read_data1(id_ex_read_data1),
        .read_data2(id_ex_read_data2), .imm_out(id_ex_imm),
        .alu_src(id_ex_alu_src),
        .branch(id_ex_valid && id_ex_branch && !rst),
        .alu_op(id_ex_alu_op), .funct3(id_ex_funct3),
        .funct7(id_ex_funct7), .result_alu(result_alu),
        .pc_branch(pc_branch), .pc_src(pc_src)
    );

    mem_stage u_mem_stage (
        .clk(clk), .mem_read(ex_mem_valid && ex_mem_mem_read && !rst),
        .mem_write(ex_mem_valid && ex_mem_mem_write && !rst),
        .address(ex_mem_result), .write_data(ex_mem_store_data),
        .read_data(read_data)
    );

    wb_stage u_wb_stage (
        .result_alu(mem_wb_result), .read_data(mem_wb_read_data),
        .mem_to_reg(mem_wb_mem_to_reg), .write_data(write_data)
    );

    // A taken branch in EX discards both younger instructions (ID and IF).
    always @(posedge clk) begin
        if (rst || pc_src) begin
            if_id_valid <= 1'b0;
            if_id_pc <= 32'b0;
            if_id_instruction <= 32'h00000013;
        end else begin
            if_id_valid <= 1'b1;
            if_id_pc <= p_out;
            if_id_instruction <= instruction;
        end
    end

    always @(posedge clk) begin
        if (rst || pc_src) begin
            id_ex_valid <= 1'b0;
            id_ex_pc <= 32'b0;
            id_ex_read_data1 <= 32'b0;
            id_ex_read_data2 <= 32'b0;
            id_ex_imm <= 32'b0;
            id_ex_rd <= 5'b0;
            id_ex_funct3 <= 3'b0;
            id_ex_funct7 <= 7'b0;
            id_ex_alu_op <= 2'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_branch <= 1'b0;
        end else begin
            id_ex_valid <= if_id_valid;
            id_ex_pc <= if_id_pc;
            id_ex_read_data1 <= read_data1;
            id_ex_read_data2 <= read_data2;
            id_ex_imm <= imm_out;
            id_ex_rd <= if_id_instruction[11:7];
            id_ex_funct3 <= if_id_instruction[14:12];
            id_ex_funct7 <= if_id_instruction[31:25];
            id_ex_alu_op <= alu_op;
            id_ex_reg_write <= reg_write;
            id_ex_alu_src <= alu_src;
            id_ex_mem_read <= mem_read;
            id_ex_mem_write <= mem_write;
            id_ex_mem_to_reg <= mem_to_reg;
            id_ex_branch <= branch;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            ex_mem_valid <= 1'b0;
            ex_mem_pc <= 32'b0;
            ex_mem_result <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_mem_to_reg <= 1'b0;
        end else begin
            ex_mem_valid <= id_ex_valid;
            ex_mem_pc <= id_ex_pc;
            ex_mem_result <= result_alu;
            ex_mem_store_data <= id_ex_read_data2;
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            mem_wb_valid <= 1'b0;
            mem_wb_pc <= 32'b0;
            mem_wb_result <= 32'b0;
            mem_wb_read_data <= 32'b0;
            mem_wb_rd <= 5'b0;
            mem_wb_reg_write <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
        end else begin
            mem_wb_valid <= ex_mem_valid;
            mem_wb_pc <= ex_mem_pc;
            mem_wb_result <= ex_mem_result;
            mem_wb_read_data <= read_data;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
        end
    end
endmodule
