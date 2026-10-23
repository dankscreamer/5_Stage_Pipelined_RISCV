# Synthesis results

Target: iCE40 HX8K (ct256). Flow: Yosys `synth_ice40` → nextpnr-ice40, 3 placement seeds per design,
median Fmax reported. Instruction and data memory: 32 words each (all designs).
Tools: Yosys 0.70+post (git sha1 0c11ea098be065e585a90a06e7b7da49936cf231, Release, AppleClang clang++ 17.0.0.17000604); nextpnr-ice40 0.11.1_2.

| Design | Fmax (MHz, median) | Clock period (ns) | Logic cells | LUT4 | Flip-flops | Block RAMs | Fmax per seed |
|---|--:|--:|--:|--:|--:|--:|---|
| Single-cycle | **34.6** | 28.9 | 5253 | 3199 | 2081 | 2 | 34.64, 35.14, 34.32 |
| Pipelined, forwarding | **48.8** | 20.5 | 1157 | 800 | 428 | 8 | 47.42, 51.17, 48.76 |
| Pipelined, no forwarding | **66.2** | 15.1 | 969 | 622 | 418 | 8 | 66.2, 67.76, 65.74 |

Critical path (median seed), source → sink cell:

- Single-cycle: `imem.memory.0.1_RAM.RDATA_2` → `rf.register[20]_SB_DFFE_Q_29_DFFLC.I0`
- Pipelined, forwarding: `fwd.mem_wb_rd_SB_DFFSR_Q_1_DFFLC.O` → `aluctrl.funct3_SB_DFFSR_Q_DFFLC.SR`
- Pipelined, no forwarding: `rf.register.1.1_RAM.RDATA_3` → `rf.register.0.1_RDATA_12_SB_DFFSR_Q_DFFLC.SR`
