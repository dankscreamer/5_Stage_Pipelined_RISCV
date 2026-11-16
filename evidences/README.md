# Simulation Evidence Catalog

This directory contains the original simulation waveform screenshots captured during the functional verification of our single-cycle RV32I processor prototype.

---

## Quick Navigation

| Stage Directory | Verified Hardware Modules | Images & Explanations |
|:---|:---|:---|
| **[Stage 1: Instruction Fetch](Stage1_Instruction_Fetch/)** | Program Counter (`pc.v`), Adder (`adder.v`), Instruction Memory (`instr_mem.v`) | - `01_pc_reset_verification.png`<br>- `02_instruction_fetch.png` |
| **[Stage 2: Instruction Decode](Stage2_Instruction_Decode/)** | Register File (`reg_file.v`), Immediate Generator (`imm_gen.v`), Control Unit (`control_unit.v`) | - `03_register_file_read.png`<br>- `04_immediate_generation.png`<br>- `05_control_unit_verification.png` |
| **[Stage 3: Execution & Memory](Stage3_Execution/)** | ALU (`alu.v`), ALU Control (`alu_control.v`), Data Memory (`data_mem.v`), Branch Unit (`branch_unit.v`), Timing | - `06_alu_arithmetic.png`<br>- `07_alu_logical.png`<br>- `08_sw_lw_waveform.png`<br>- `09_data_memory_read_verification.png`<br>- `11_beq_taken_verification.png`<br>- `performance.png` |

---

## Summary of All Evidence Waveforms

Each subfolder contains its own detailed `README.md` explaining:
- **A short summary** of what the image establishes.
- **The key signals to watch** and their numerical values.
- **The hardware logic behind it** (which lines of Verilog are executing and why).
