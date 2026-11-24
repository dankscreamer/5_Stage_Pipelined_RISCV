# Phase 2: matches program_phase2_memory.hex.
.text
.globl _start
_start:
    addi x1, x0, 42
    nop
    nop
    nop
    sw x1, 0(x0)        # x1 has reached WB before the SW's ID stage.
    lw x2, 0(x0)        # Reads the word after SW's MEM write edge.
