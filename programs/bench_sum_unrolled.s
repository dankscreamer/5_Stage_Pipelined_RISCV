# BENCHMARK: the same 64-word sum, loop unrolled 8x with all loads issued first:
# no load-use stalls and 8x fewer taken branches.
    addi x1, x0, 0       # pointer
    addi x2, x0, 1       # value
    addi x3, x0, 256     # end pointer (64 words)
fill:
    sw   x2, 0(x1)
    addi x2, x2, 3
    addi x1, x1, 4
    bne  x1, x3, fill
    addi x1, x0, 0
    addi x10, x0, 0      # sum
sum:
    lw   x11, 0(x1)
    lw   x12, 4(x1)
    lw   x13, 8(x1)
    lw   x14, 12(x1)
    lw   x15, 16(x1)
    lw   x16, 20(x1)
    lw   x17, 24(x1)
    lw   x18, 28(x1)
    add  x10, x10, x11
    add  x10, x10, x12
    add  x10, x10, x13
    add  x10, x10, x14
    add  x10, x10, x15
    add  x10, x10, x16
    add  x10, x10, x17
    add  x10, x10, x18
    addi x1, x1, 32
    bne  x1, x3, sum
    sw   x10, 512(x0)
    halt
