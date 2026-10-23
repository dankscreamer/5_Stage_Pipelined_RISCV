# Store 1..10 into memory, then sum it with a load loop. Result 55 stored at 0x100.
    addi x1, x0, 0       # pointer
    addi x2, x0, 1       # value
    addi x3, x0, 11      # limit
fill:
    sw   x2, 0(x1)
    addi x1, x1, 4
    addi x2, x2, 1
    bne  x2, x3, fill
    addi x1, x0, 0       # pointer
    addi x4, x0, 40      # end pointer
    addi x5, x0, 0       # sum
sum:
    lw   x6, 0(x1)
    add  x5, x5, x6
    addi x1, x1, 4
    bne  x1, x4, sum
    sw   x5, 256(x0)
    lw   x7, 256(x0)
    halt
