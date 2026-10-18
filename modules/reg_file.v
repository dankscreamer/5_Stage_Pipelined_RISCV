module reg_file (
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

assign read_data1=(rs1==5'b0)? 32'b0 : register[rs1];
assign read_data2=(rs2==5'b0)? 32'b0 : register[rs2];

always @(posedge clk) begin
    if (write_enable && (rd !=5'b0))begin
        register[rd]<=write_data;
    end

    
    
end

endmodule