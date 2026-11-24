# Phase 2: matches program_phase2_arithmetic.hex.
# Three NOPs after the last producer; no forwarding or hardware stalls.
.text
.globl _start
_start:
    addi x1, x0, 5
    addi x2, x0, 10
    nop
    nop
    nop
    add x3, x1, x2       # 15
    sub x4, x1, x2       # -5
    and x5, x1, x2       # 0
    or  x6, x1, x2       # 15
    xor x7, x1, x2       # 15
