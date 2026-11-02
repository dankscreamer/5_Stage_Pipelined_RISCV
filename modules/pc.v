module pc(
    input wire clk,rst,
    input wire [31:0]p_nxt,
    output reg [31:0]p_out



);
always @(posedge clk) begin
    if(rst==1)begin
        p_out=31'b00;


     end
    else begin 
        p_out=p_nxt;
    end 
    
end



endmodule