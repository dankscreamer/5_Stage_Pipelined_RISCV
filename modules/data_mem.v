module data_mem (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data
);

    reg [31:0] memory [0:63];

    always @(posedge clk) begin
        if (mem_write == 1'b1) begin
            memory[address[7:2]] <= write_data;
        end
    end

    always @(*) begin
        if (mem_read == 1'b1) begin
            read_data = memory[address[7:2]];
        end
        else begin
            read_data = 32'b0;
        end
    end

endmodule