module instr_mem (
    input  wire [31:0] read_address,
    output wire [31:0] instruction
);

    reg [31:0] memory [0:63];
    reg [1023:0] program_file;
    integer i;

    initial begin
        // Unused locations contain NOPs. PROGRAM is a simulation-only override.
        for (i = 0; i < 64; i = i + 1)
            memory[i] = 32'h00000013;
        if (!$value$plusargs("PROGRAM=%s", program_file))
            program_file = "program.hex";
        $readmemh(program_file, memory);
    end

    assign instruction = memory[read_address[7:2]];

endmodule
