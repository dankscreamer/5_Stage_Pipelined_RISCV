# 5-Stage Pipelined RISC-V Processor

**Project Date:** October 17–22, 2026  
**Architecture:** 5-Stage Pipelined RISC-V (`IF-ID-EX-MEM-WB`)  
**Target Instruction Set:** RV32I Subset

---

## Phase 1 — ALU Implementation

**Date:** October 17, 2026

### 1. What Was Done Today

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

### 1. What Was Done Today

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

### 1. What Was Done Today

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

### 3. Initial RTL (`rtl/imm_gen.v` — v1)

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

## Phase 1 — Immediate Generator Refactoring & Full Format Expansion

**Date:** October 21, 2026

### 1. What Was Done Today

- Identified a key structural redundancy while expanding `imm_gen.v` toward B-type (`src == 2'b10`) and J-type (`src == 2'b11`) support: checking `if (instruction[31] == 0)` repeatedly inside every `src` branch was duplicating the exact same sign-bit check across multiple blocks.
- Refactored `imm_gen.v` to evaluate the MSB (`instruction[31]`) **only once** at the top of the combinational block using a dedicated 20-bit intermediate padding register (`reg [19:0] pad`).
- Replaced the nested `if-else` trees inside each instruction format branch with clean, single-line concatenations utilizing `pad` (and sliced subsets `pad[18:0]` and `pad[10:0]`).
- Completed full bit-distribution support for **I-type, S-type, B-type, and J-type** formats and ensured full `else` coverage to prevent latch inference.

### 2. Design Realization & Why It Matters

1. **Architectural Consistency in RISC-V:** Because the RISC-V ISA intentionally places the immediate sign bit at `instruction[31]` across all immediate instruction formats (I, S, B, U, J), the sign-extension decision is completely independent of `src`.
2. **Factoring Out Common Logic:** By decoupling the **sign-bit evaluation** from the **bit-field extraction**, we eliminate repetitive nested `if-else` blocks. `pad` is computed once (`20'b0` for positive, `20'hFFFFF` for negative) and reused across every format below it.
3. **Cleaner Hardware & Scalability:** As more instruction formats are added, we slice the exact number of upper sign-extension bits needed from `pad`, keeping the RTL compact, readable, and aligned with real hardware multiplexing.

### 3. Instruction Formats & Bit Distributions

#### 1. I-Type (`src == 2'b00`) — e.g., `ADDI`, `LW`
- **Bit Distribution:** Contiguous 12-bit field (`instruction[31:20]`) padded with 20 sign bits (`pad`).
- **RTL Implementation:**
```verilog
out = {pad, instruction};
```

#### 2. S-Type (`src == 2'b01`) — e.g., `SW`
- **Bit Distribution:** Split 7-bit upper field (`instruction[31:25]`) and 5-bit lower field (`instruction[11:7]`) padded with 20 sign bits (`pad`).
- **RTL Implementation:**
```verilog
out = {pad, instruction, instruction[11:7]};
```

#### 3. B-Type (`src == 2'b10`) — e.g., `BEQ`, `BNE`
- **Bit Distribution:** 13-bit signed branch offset (`imm[12]` at `[31]`, `imm[11]` at `[7]`, `imm[10:5]` at `[30:25]`, `imm[4:1]` at `[11:8]`, and `imm[0]` hardwired to `1'b0`), padded with 19 sign bits (`pad[18:0]`).
- **RTL Implementation:**
```verilog
out = {pad[18:0], instruction[31], instruction[7], instruction, instruction[11:8], 1'b0};
```

#### 4. J-Type (`src == 2'b11`) — e.g., `JAL`
- **Bit Distribution:** 21-bit signed jump offset (`imm[20]` at `[31]`, `imm[19:12]` at `[19:12]`, `imm[11]` at `[20]`, `imm[10:1]` at `[30:21]`, and `imm[0]` hardwired to `1'b0`), padded with 11 sign bits (`pad[10:0]`).
- **RTL Implementation:**
```verilog
out = {pad[10:0], instruction[31], instruction, instruction[20], instruction, 1'b0};
```

### 4. Current RTL (`rtl/imm_gen.v` — Final)

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

---

## Phase 1 — ALU Control Unit Implementation

**Date:** October 22, 2026

### 1. What Was Done Today

- Designed and implemented the combinational **ALU Control Unit (`alu_control.v`)** in Verilog.
- Mapped the 2-bit category selector (`alu_op`) alongside `funct3` (`instruction[14:12]`) and `funct7` (`instruction[31:25]`) to drive the 4-bit `control_alu` signal into the ALU.
- Structured the decoding logic using explicit `if-else` trees with a safe default assignment at the top of the combinational block to prevent latch inference.

### 2. How It Works

In a two-level RISC-V control scheme, the Main Control Unit inspects the instruction `opcode` and sends a 2-bit `alu_op` category code to `alu_control`. The ALU Control Unit then resolves the exact 4-bit hardware operation:

| `alu_op` | `funct3` | `funct7[5]` (`instruction[30]`) | Instruction Category / Target | Operation | `control_alu` |
|:---:|:---:|:---:|---|---|:---:|
| `2'b00` | *Any* | *Any* | `LW`, `SW` (Memory Address Offset) | ADD | `4'b0010` |
| `2'b01` | *Any* | *Any* | `BEQ`, `BNE` (Branch Comparison) | SUB | `4'b0110` |
| `2'b10` | `3'b000` | `1'b0` | `ADD` | ADD | `4'b0010` |
| `2'b10` | `3'b000` | `1'b1` | `SUB` | SUB | `4'b0110` |
| `2'b10` | `3'b111` | *Any* | `AND`, `ANDI` | AND | `4'b0000` |
| `2'b10` | `3'b110` | *Any* | `OR`, `ORI` | OR | `4'b0001` |
| `2'b10` | `3'b100` | *Any* | `XOR`, `XORI` | XOR | `4'b0100` |

### 3. Current RTL (`rtl/alu_control.v`)

```verilog
module alu_control (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [3:0] control_alu
);

    always @(*) begin
        control_alu = 4'b0010;

        if (alu_op == 2'b00) begin
            control_alu = 4'b0010;
        end
        else if (alu_op == 2'b01) begin
            control_alu = 4'b0110;
        end
        else if (alu_op == 2'b10) begin
            if (funct3 == 3'b000) begin
                if (funct7[5] == 1'b1) begin
                    control_alu = 4'b0110;
                end
                else begin
                    control_alu = 4'b0010;
                end
            end
            else if (funct3 == 3'b111) begin
                control_alu = 4'b0000;
            end
            else if (funct3 == 3'b110) begin
                control_alu = 4'b0001;
            end
            else if (funct3 == 3'b100) begin
                control_alu = 4'b0100;
            end
            else begin
                control_alu = 4'b0010;
            end
        end
        else begin
            control_alu = 4'b0010;
        end
    end

endmodule
```

---

## Remaining Roadmap & Required Modules

- [ ] **Main Control Unit (`control_unit.v`):** Decode `opcode` (`instruction[6:0]`) to generate `reg_write`, `imm_src`, `alu_src`, `mem_write`, `result_src`, `branch`, and `alu_op`.
- [ ] **Fetch Stage (`pc.v` & `instr_mem.v`):** Program Counter register, `PC + 4` adder, branch target adder, and Instruction Memory array.
- [ ] **Data Memory (`data_mem.v`):** Synchronous write / asynchronous read memory block for `LW` and `SW`.
- [ ] **Pipeline Registers (`if_id`, `id_ex`, `ex_mem`, `mem_wb`):** Stage isolation registers to hold instruction data and control signals across clock cycles.
- [ ] **Hazard Detection & Forwarding Unit:** Data forwarding muxes and stall/flush logic to resolve RAW (Read-After-Write) and control hazards.

# 5-Stage Pipelined RISC-V Processor

**Project Date:** October 17–23, 2026  
**Architecture:** 5-Stage Pipelined RISC-V (`IF-ID-EX-MEM-WB`)  
**Target Instruction Set:** RV32I Subset

---

## Phase 1 — ALU Implementation

**Date:** October 17, 2026

### 1. What Was Done Today

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

### 1. What Was Done Today

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

### 1. What Was Done Today

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

### 3. Initial RTL (`rtl/imm_gen.v` — v1)

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

## Phase 1 — Immediate Generator Refactoring & Full Format Expansion

**Date:** October 21, 2026

### 1. What Was Done Today

- Identified a key structural redundancy while expanding `imm_gen.v` toward B-type (`src == 2'b10`) and J-type (`src == 2'b11`) support: checking `if (instruction[31] == 0)` repeatedly inside every `src` branch was duplicating the exact same sign-bit check across multiple blocks.
- Refactored `imm_gen.v` to evaluate the MSB (`instruction[31]`) **only once** at the top of the combinational block using a dedicated 20-bit intermediate padding register (`reg [19:0] pad`).
- Replaced the nested `if-else` trees inside each instruction format branch with clean, single-line concatenations utilizing `pad` (and sliced subsets `pad[18:0]` and `pad[10:0]`).
- Completed full bit-distribution support for **I-type, S-type, B-type, and J-type** formats and ensured full `else` coverage to prevent latch inference.

### 2. Design Realization & Why It Matters

1. **Architectural Consistency in RISC-V:** Because the RISC-V ISA intentionally places the immediate sign bit at `instruction[31]` across all immediate instruction formats (I, S, B, U, J), the sign-extension decision is completely independent of `src`.
2. **Factoring Out Common Logic:** By decoupling the **sign-bit evaluation** from the **bit-field extraction**, we eliminate repetitive nested `if-else` blocks. `pad` is computed once (`20'b0` for positive, `20'hFFFFF` for negative) and reused across every format below it.
3. **Cleaner Hardware & Scalability:** As more instruction formats are added, we slice the exact number of upper sign-extension bits needed from `pad`, keeping the RTL compact, readable, and aligned with real hardware multiplexing.

### 3. Instruction Formats & Bit Distributions

#### 1. I-Type (`src == 2'b00`) — e.g., `ADDI`, `LW`
- **Bit Distribution:** Contiguous 12-bit field (`instruction[31:20]`) padded with 20 sign bits (`pad`).
- **RTL Implementation:**
```verilog
out = {pad, instruction};
```

#### 2. S-Type (`src == 2'b01`) — e.g., `SW`
- **Bit Distribution:** Split 7-bit upper field (`instruction[31:25]`) and 5-bit lower field (`instruction[11:7]`) padded with 20 sign bits (`pad`).
- **RTL Implementation:**
```verilog
out = {pad, instruction, instruction[11:7]};
```

#### 3. B-Type (`src == 2'b10`) — e.g., `BEQ`, `BNE`
- **Bit Distribution:** 13-bit signed branch offset (`imm[12]` at `[31]`, `imm[11]` at `[7]`, `imm[10:5]` at `[30:25]`, `imm[4:1]` at `[11:8]`, and `imm[0]` hardwired to `1'b0`), padded with 19 sign bits (`pad[18:0]`).
- **RTL Implementation:**
```verilog
out = {pad[18:0], instruction[31], instruction[7], instruction, instruction[11:8], 1'b0};
```

#### 4. J-Type (`src == 2'b11`) — e.g., `JAL`
- **Bit Distribution:** 21-bit signed jump offset (`imm[20]` at `[31]`, `imm[19:12]` at `[19:12]`, `imm[11]` at `[20]`, `imm[10:1]` at `[30:21]`, and `imm[0]` hardwired to `1'b0`), padded with 11 sign bits (`pad[10:0]`).
- **RTL Implementation:**
```verilog
out = {pad[10:0], instruction[31], instruction, instruction[20], instruction, 1'b0};
```

### 4. Current RTL (`rtl/imm_gen.v` — Final)

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

---

## Phase 1 — ALU Control Unit Implementation

**Date:** October 22, 2026

### 1. What Was Done Today

- Designed and implemented the combinational **ALU Control Unit (`alu_control.v`)** in Verilog.
- Mapped the 2-bit category selector (`alu_op`) alongside `funct3` (`instruction[14:12]`) and `funct7` (`instruction[31:25]`) to drive the 4-bit `control_alu` signal into the ALU.
- Structured the decoding logic using explicit `if-else` trees with a safe default assignment at the top of the combinational block to prevent latch inference.

### 2. How It Works

In a two-level RISC-V control scheme, the Main Control Unit inspects the instruction `opcode` and sends a 2-bit `alu_op` category code to `alu_control`. The ALU Control Unit then resolves the exact 4-bit hardware operation:

| `alu_op` | `funct3` | `funct7[5]` (`instruction[30]`) | Instruction Category / Target | Operation | `control_alu` |
|:---:|:---:|:---:|---|---|:---:|
| `2'b00` | *Any* | *Any* | `LW`, `SW` (Memory Address Offset) | ADD | `4'b0010` |
| `2'b01` | *Any* | *Any* | `BEQ`, `BNE` (Branch Comparison) | SUB | `4'b0110` |
| `2'b10` | `3'b000` | `1'b0` | `ADD` | ADD | `4'b0010` |
| `2'b10` | `3'b000` | `1'b1` | `SUB` | SUB | `4'b0110` |
| `2'b10` | `3'b111` | *Any* | `AND`, `ANDI` | AND | `4'b0000` |
| `2'b10` | `3'b110` | *Any* | `OR`, `ORI` | OR | `4'b0001` |
| `2'b10` | `3'b100` | *Any* | `XOR`, `XORI` | XOR | `4'b0100` |

### 3. Current RTL (`rtl/alu_control.v`)

```verilog
module alu_control (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [3:0] control_alu
);

    always @(*) begin
        control_alu = 4'b0010;

        if (alu_op == 2'b00) begin
            control_alu = 4'b0010;
        end
        else if (alu_op == 2'b01) begin
            control_alu = 4'b0110;
        end
        else if (alu_op == 2'b10) begin
            if (funct3 == 3'b000) begin
                if (funct7[5] == 1'b1) begin
                    control_alu = 4'b0110;
                end
                else begin
                    control_alu = 4'b0010;
                end
            end
            else if (funct3 == 3'b111) begin
                control_alu = 4'b0000;
            end
            else if (funct3 == 3'b110) begin
                control_alu = 4'b0001;
            end
            else if (funct3 == 3'b100) begin
                control_alu = 4'b0100;
            end
            else begin
                control_alu = 4'b0010;
            end
        end
        else begin
            control_alu = 4'b0010;
        end
    end

endmodule
```

---

## Phase 1 — Instruction Memory Implementation

**Date:** October 23, 2026

### 1. What Was Done Today

- Designed and implemented the **Instruction Memory (`instr_mem.v`)** module for the Instruction Fetch (`IF`) stage[cite: 1].
- Configured a 64-word (32-bit wide) storage array (`reg [31:0] memory [0:63]`) with continuous asynchronous read access.
- Implemented word-aligned addressing (`read_address[7:2]`) to map byte-addressed Program Counter (`PC`) values directly to 32-bit instruction entries[cite: 1].
- Added an `initial` block utilizing `$readmemh("program.hex", memory)` to preload machine-code test programs during simulation.

### 2. Design Choices & How It Works

#### 1. Asynchronous Combinational Read
During normal operation, Instruction Memory acts as a read-only lookup table. As soon as the Program Counter (`PC`) presents a new `read_address`, the corresponding 32-bit `instruction` word is driven onto the output bus without waiting for a clock edge[cite: 1].

#### 2. Word-Aligned Indexing (`read_address[7:2]`)
Because RISC-V memory is byte-addressed and every RV32I instruction is 4 bytes (32 bits) wide, sequential `PC` addresses increment by 4 (`0x00`, `0x04`, `0x08`, `0x0C`)[cite: 1]. Rather than wasting space declaring an array of individual bytes, `memory` is structured as an array of 32-bit words:
- **`read_address[1:0]` (Byte Offset):** Discarded, as instructions are aligned on 4-byte boundaries.
- **`read_address[7:2]` (Word Index):** Extracts the 6-bit word index ($2^6 = 64$ words), dividing the byte address by 4 in hardware with zero gate delay.

### 3. Current RTL (`rtl/instr_mem.v`)

```verilog
module instr_mem (
    input  wire [31:0] read_address,
    output wire [31:0] instruction
);

    reg [31:0] memory;

    initial begin
        $readmemh("program.hex", memory);
    end

    assign instruction = memory[read_address[7:2]];

endmodule
```

---

## Remaining Roadmap & Required Modules

- [ ] **Program Counter (`pc.v`):** Synchronous 32-bit register with reset and next-PC (`PC + 4` or branch target) selection logic to complete the `IF` stage[cite: 1].
- [ ] **Main Control Unit (`control_unit.v`):** Decode `opcode` (`instruction[6:0]`) to generate `reg_write`, `imm_src`, `alu_src`, `mem_write`, `result_src`, `branch`, and `alu_op`[cite: 1].
- [ ] **Data Memory (`data_mem.v`):** Synchronous write / asynchronous read memory block for `LW` and `SW`[cite: 1].
- [ ] **Pipeline Registers (`if_id`, `id_ex`, `ex_mem`, `mem_wb`):** Stage isolation registers to hold instruction data and control signals across clock cycles.
- [ ] **Hazard Detection & Forwarding Unit:** Data forwarding muxes and stall/flush logic to resolve RAW (Read-After-Write) and control hazards.