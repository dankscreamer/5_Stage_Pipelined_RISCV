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

## Phase 1 — Immediate Generator Implementation

**Date:** October 20, 2026

1. ###What Was Done Today

- Designed and implemented the combinational **Immediate Generator (`imm_gen.v`)** in Verilog.
- Explicitly implemented **only I-type and S-type instruction formats** today (`ADDI`, `LW`, and `SW`).
- Built custom, step-by-step `if-else` sign-extension logic rather than relying on condensed replication shorthand, making the hardware behavior transparent and easy to trace.
- Added a default output assignment (`out = 32'b0`) at the top of the combinational block to prevent unintended latch inference.

### 2. Design Choices & How It Works

#### Explicit Sign-Extension (`if-else` Architecture)

Instead of hiding sign-extension behind nested replication operators, the module explicitly inspects the sign bit (`instruction[31]`):
- **Positive Immediates (`instruction[31] == 0`):** The upper 20 bits are explicitly padded with zeros (`20'b0`) and concatenated with the 12-bit immediate.
- **Negative Immediates (`instruction[31] == 1`):** To preserve two's complement negative values across 32 bits, the upper 20 bits are explicitly padded with ones (`20'hFFFFF`) and concatenated with the 12-bit immediate.

#### Immediate Source Control Codes (`src`)

| `src` | Format | Target Instructions | Immediate Bit Mapping |
|:---:|:---:|---|---|
| `2'b00` | **I-Type** | `ADDI`, `LW` | `instruction[31:20]` (contiguous 12-bit field) |
| `2'b01` | **S-Type** | `SW` | `{instruction[31:25], instruction[11:7]}` (split 7-bit + 5-bit fields) |

*Note: Only I-type and S-type instructions were implemented today. B-type (`2'b10`) for branches will be added in a subsequent session.*

### 3. Current RTL (`rtl/imm_gen.v`)

```verilog
module imm_gen (
    input  wire [31:0] instruction,
    input  wire [1:0]  src,
    output reg  [31:0] out
);

    always @(*) begin 
        // Default output to prevent unwanted latches
        out = 32'b0;

        // I-type instructions (e.g., ADDI, LW)
        if (src == 2'b00) begin 
            if (instruction[31] == 0) begin
                out = {20'b0, instruction};
            end
            else begin 
                out = {20'hFFFFF, instruction};
            end
        end
        
        // S-type instructions (e.g., SW)
        else if (src == 2'b01) begin
            if (instruction[31] == 0) begin
                out = {20'b0, instruction, instruction[11:7]};
            end
            else begin
                out = {20'hFFFFF, instruction, instruction[11:7]};
            end
        end
    end

endmodule
```

---

## Phase 1 — Immediate Generator Refactoring & Optimization

**Date:** October 21, 2026

1. ###What Was Done Today

- Identified a key structural redundancy while expanding `imm_gen.v` toward B-type (`src == 2'b10`) support: checking `if (instruction[31] == 0)` repeatedly inside every `src` branch was duplicating the exact same sign-bit check across multiple blocks.
- Refactored `imm_gen.v` to evaluate the MSB (`instruction[31]`) **only once** at the top of the combinational block using a dedicated 20-bit intermediate padding register (`reg [19:0] pad`).
- Replaced the nested `if-else` trees inside each instruction format branch with clean, single-line concatenations utilizing `pad`.
- Added the structural branch placeholder for `src == 2'b10` (B-type) and ensured full `else` coverage to prevent latch inference.

### 2. Design Realization & Why It Matters

1. **Architectural Consistency in RISC-V:** Because the RISC-V ISA intentionally places the immediate sign bit at `instruction[31]` across all immediate instruction formats (I, S, B, U, J), the sign-extension decision is completely independent of `src`.
2. **Factoring Out Common Logic:** By decoupling the **sign-bit evaluation** from the **bit-field extraction**, we eliminate repetitive nested `if-else` blocks. `pad` is computed once (`20'b0` for positive, `20'hFFFFF` for negative) and reused across every format below it.
3. **Cleaner Hardware & Scalability:** As more instruction formats (like B-type) are added, we no longer need to rewrite the positive/negative `if-else` check for each one—keeping the RTL compact, readable, and aligned with real hardware multiplexing.

### 3. Current RTL (`rtl/imm_gen.v`)

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
            out = 32'b0; 
        end
        else begin
            out = 32'b0;
        end
    end

endmodule
```