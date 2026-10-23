# Synthesis results

Target: iCE40 HX8K (ct256). Flow: Yosys `synth_ice40` → nextpnr-ice40, 3 placement seeds per design,
median Fmax reported. Instruction and data memory: 32 words each (all designs).
Tools: Yosys 0.70+post (git sha1 0c11ea098be065e585a90a06e7b7da49936cf231, Release, AppleClang clang++ 17.0.0.17000604); nextpnr-ice40 0.11.1_2.

| Design | Fmax (MHz, median) | Clock period (ns) | Logic cells | LUT4 | Flip-flops | Block RAMs | Fmax per seed |
|---|--:|--:|--:|--:|--:|--:|---|
| Single-cycle | **34.6** | 28.9 | 5253 | 3199 | 2081 | 2 | 34.64, 35.14, 34.32 |
| Pipelined, forwarding | **54.2** | 18.4 | 1161 | 804 | 428 | 8 | 54.22, 54.76, 53.73 |
| Pipelined, no forwarding | **71.5** | 14.0 | 966 | 619 | 418 | 8 | 71.02, 72.71, 71.51 |
| Pipelined, forwarding, static prediction | **51.9** | 19.3 | 1306 | 941 | 429 | 8 | 52.96, 50.05, 51.86 |
| Pipelined, forwarding, dynamic prediction (8-entry BTB) | **49.2** | 20.3 | 2072 | 1443 | 706 | 10 | 49.19, 49.85, 49.23 |

Critical path (median seed), source → sink cell:

- Single-cycle: `imem.memory.0.1_RAM.RDATA_2` → `rf.register[20]_SB_DFFE_Q_29_DFFLC.I0`
- Pipelined, forwarding: `dmem.memory.0.0_RAM.RDATA_2` → `id_ex_reg.mem_write_out_SB_DFFSR_Q_D_SB_LUT4_O_LC.SR`
- Pipelined, no forwarding: `rf.register.1.0_RAM.RDATA_0` → `id_ex_reg.branch_out_SB_DFFSR_Q_DFFLC.SR`
- Pipelined, forwarding, static prediction: `dmem.memory.0.1_RAM.RDATA_3` → `id_ex_reg.pc_in_SB_DFFESR_Q_8_DFFLC.SR`
- Pipelined, forwarding, dynamic prediction (8-entry BTB): `dmem.memory.0.1_RAM.RDATA_7` → `g_btb.bp.tag[3]_SB_DFFE_Q_7_DFFLC.CEN`
