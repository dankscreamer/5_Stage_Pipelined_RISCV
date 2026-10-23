// BYPASS = 1 : a write and a read of the same register in the same cycle returns the
//              new value (needed in the pipeline, where WB and ID overlap).
// BYPASS = 0 : plain register file. The single-cycle CPU must use this, because there
//              write_data depends on read_data, so a bypass would form a combinational loop.
module reg_file #(
    parameter BYPASS = 0
) (
    input  wire        clk,
    input  wire        write_enable,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] write_data,

    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);

reg [31:0]register [31:0];

integer i;
initial begin
    for (i = 0; i < 32; i = i + 1) begin
        register[i] = 32'b0;
    end
end

wire fwd1 = BYPASS && write_enable && (rd != 5'b0) && (rd == rs1);
wire fwd2 = BYPASS && write_enable && (rd != 5'b0) && (rd == rs2);

assign read_data1=(rs1==5'b0)? 32'b0 : (fwd1 ? write_data : register[rs1]);
assign read_data2=(rs2==5'b0)? 32'b0 : (fwd2 ? write_data : register[rs2]);

always @(posedge clk) begin
    if (write_enable && (rd !=5'b0))begin
        register[rd]<=write_data;
    end
end

endmodule
