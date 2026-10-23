// Data memory: DEPTH words (default 256 = 1 KB), synchronous write, asynchronous read,
// word-aligned.
module data_mem #(
    parameter DEPTH = 256
) (
    input  wire        clk,
    input  wire        mem_write,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);

    localparam AW = $clog2(DEPTH);

    reg [31:0] memory [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            memory[i] = 32'b0;
        end
    end

    assign read_data = memory[address[AW+1:2]];

    always @(posedge clk) begin
        if (mem_write) begin
            memory[address[AW+1:2]] <= write_data;
        end
    end

endmodule
