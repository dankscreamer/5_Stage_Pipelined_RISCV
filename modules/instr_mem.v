module instr_mem (
    input  wire [31:0] read_address,
    output wire [31:0] instruction
);

    reg [31:0] memory [0:63];

    initial begin
        $readmemh("program.hex", memory);
    end

    assign instruction = memory[read_address[7:2]];

endmodule