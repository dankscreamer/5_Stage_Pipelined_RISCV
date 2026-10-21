# 5-Stage Pipelined RISC-V Processor

**Project Date:** October 17–21, 2026  
**Architecture:** 5-Stage Pipelined RISC-V (`IF-ID-EX-MEM-WB`)  
**Target Instruction Set:** RV32I Subset

---

## Phase 1 — ALU Implementation

**Date:** October 17, 2026

1. ###What Was Done Today

- Selected the **5-Stage Pipelined RISC-V (`IF-ID-EX-MEM-WB`)** architecture and mapped the target RV32I subset: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `ADDI`, `LW`, `SW`, `BEQ`, `BNE`.
- Analyzed RISC-V instruction formats (`opcode`, `rd`, `rs1`, `rs2`, and split immediates).
- Implemented the 32-bit combinational `ALU_RISCV` module in Verilog.

### 2. Why Start with the ALU?

1. **Zero Dependencies:** It is a pure combinational leaf module requiring no clocks, memory, or pipeline registers.
2. **Core Engine:** Handles arithmetic/logic (`ADD`, `SUB`, `AND`, `OR`, `XOR`), memory address calculation (`LW`/`SW`), and branch comparisons (`BEQ`/`BNE`).
3. **Control Anchor:** Defines the 4-bit control codes that the Control Unit will target.

### 3. How It Works

All arithmetic and bitwise sub-circuits evaluate in parallel as soon as inputs `a` and `b` arrive. The 4-bit `control_alu` signal acts as a multiplexer selector to route the chosen operation to `result_alu`.

#### ALU Control Codes

| `control_alu` | Operation | Expression |
|:---:|---|---|
| `4'b0000` | AND | `a & b` |
| `4'b0001` | OR | `a \| b` |
| `4'b0010` | ADD | `a + b` |
| `4'b0110` | SUB | `a - b` |
| `4'b0100` | XOR | `a ^ b` |

The `zero` flag asserts high (`1'b1`) whenever `result_alu == 0`, providing a direct comparison output for branch instructions (`BEQ`/`BNE`).

---

## Phase 1 — Register File Implementation

**Date:** October 18, 2026

1. ###What Was Done Today

- Designed and implemented the **32×32 Register File (`reg_file.v`)** supporting dual asynchronous read ports and a single synchronous write port.
- Enforced the RISC-V architectural rule that **register `x0` must permanently read as zero** and be immune to accidental overwrites.
- Added write-enable safety checks combined with address protection (`rd != 5'b0`) during clock-edge updates.

### 2. How It Works

#### Asynchronous Reads

`read_data1` and `read_data2` evaluate continuously. If the requested address (`rs1` or `rs2`) is `5'b0`, the hardware bypasses the register array and outputs `32'b0` directly.

#### Synchronous Writes

On the positive edge of the clock (`posedge clk`), if `write_enable` is high and `rd` is not `x0`, `write_data` is stored into `register[rd]`.

### 3. Current RTL (`rtl/reg_file.v`)

```verilog
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

    reg [31:0] register [31:0];

    assign read_data1 = (rs1 == 5'b0) ? 32'b0 : register[rs1];
    assign read_data2 = (rs2 == 5'b0) ? 32'b0 : register[rs2];

    always @(posedge clk) begin
        if (write_enable && (rd != 5'b0)) begin
            register[rd] <= write_data;
        end
    end

endmodule
```

---

## Phase 1 — Immediate Generator Implementation & Optimization

**Date:** October 20–21, 2026

1. ###What Was Done Today

- Designed and implemented the combinational **Immediate Generator (`imm_gen.v`)** supporting I, S, B, and J instruction formats.
- Refactored the module to evaluate the sign bit (`instruction[31]`) **once** via a shared `pad` register, eliminating redundant checks and keeping hardware clean.
- Mapped out the bit distributions for all target formats to ensure correct two's complement sign-extension and alignment.

### 2. Instruction Formats & Bit Distributions

#### 1. I-Type (`src == 2'b00`) — e.g., `ADDI`, `LW`
* **Bit Distribution:** Contiguous 12-bit field.
* **RTL Implementation:**
```verilog
out = {pad, instruction};
```

#### 2. S-Type (`src == 2'b01`) — e.g., `SW`
* **Bit Distribution:** Split 7-bit upper field (`31:25`) and 5-bit lower field (`11:7`).
* **RTL Implementation:**
```verilog
out = {pad, instruction, instruction[11:7]};
```

#### 3. B-Type (`src == 2'b10`) — e.g., `BEQ`, `BNE`
* **Bit Distribution:** 13-bit offset requiring a 19-bit pad (`pad[18:0]`), with bit 0 hardwired to `1'b0`.
* **RTL Implementation:**
```verilog
out = {pad[18:0], instruction[31], instruction[7], instruction, instruction[11:8], 1'b0};
```

#### 4. J-Type (`src == 2'b11`) — e.g., `JAL`
* **Bit Distribution:** 21-bit offset requiring an 11-bit pad (`pad[10:0]`), with bit 0 hardwired to `1'b0`.
* **RTL Implementation:**
```verilog
out = {pad[10:0], instruction[31], instruction, instruction[20], instruction, 1'b0};
```

### 3. Complete RTL (`rtl/imm_gen.v`)

```verilog
module imm_gen (
    input  wire [31:0] instruction,
    input  wire [1:0]  src,
    output reg  [31:0] out
);

    reg [19:0] pad;

    always @(*) begin 
        if (instruction[31] == 1'b0) begin
            pad = 20'b0;
        end
        else begin
            pad = 20'hFFFFF;
        end

        if (src == 2'b00) begin
            out = {pad, instruction};
        end
        else if (src == 2'b01) begin
            out = {pad, instruction, instruction[11:7]};
        end
        else if (src == 2'b10) begin
            out = {pad[18:0], instruction[31], instruction[7], instruction, instruction[11:8], 1'b0};
        end
        else if (src == 2'b11) begin
            out = {pad[10:0], instruction[31], instruction, instruction[20], instruction, 1'b0};
        end
        else begin
            out = 32'b0;
        end
    end

endmodule
```