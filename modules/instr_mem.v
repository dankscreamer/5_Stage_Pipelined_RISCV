// Instruction memory: DEPTH words, asynchronous read, word-aligned.
// MEM_FILE is loaded at start-up if given; testbenches can instead load a program with
// $readmemh(<file>, <dut>.imem.memory). The synchronous write port is a program-load
// port. Tie write_enable to 0 in normal use. It also stops synthesis from treating
// the memory as a constant ROM and optimising away logic the loaded program never uses.
module instr_mem #(
    parameter MEM_FILE = "",
    parameter DEPTH    = 256
) (
    input  wire        clk,
    input  wire        write_enable,
    input  wire [31:0] write_address,
    input  wire [31:0] write_data,
    input  wire [31:0] read_address,
    output wire [31:0] instruction
);

    localparam AW = $clog2(DEPTH);

    reg [31:0] memory [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            memory[i] = 32'h00000013; // NOP (addi x0, x0, 0)
        end
        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, memory);
        end
    end

    assign instruction = memory[read_address[AW+1:2]];

    always @(posedge clk) begin
        if (write_enable) begin
            memory[write_address[AW+1:2]] <= write_data;
        end
    end

endmodule
