# Phase 2: matches program_phase2_branch.hex.
.text
.globl _start
_start:
    addi x1, x0, 5      # PC 0
    addi x2, x0, 5      # PC 4
    nop                 # PC 8
    nop                 # PC 12
    nop                 # PC 16
    beq x1, x2, target  # PC 20; offset +8. EX resolves this branch.
    addi x3, x0, 99     # PC 24; flushed, so x3 is not written.
target:
    addi x4, x0, 10     # PC 28; fetched again after branch redirection.
