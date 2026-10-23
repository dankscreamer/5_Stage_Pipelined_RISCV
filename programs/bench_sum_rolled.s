# BENCHMARK: sum 64 words with a simple loop (1 element per iteration):
# a load-use stall and a taken branch (2-cycle flush) every iteration.
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
    lw   x5, 0(x1)
    add  x10, x10, x5
    addi x1, x1, 4
    bne  x1, x3, sum
    sw   x10, 512(x0)
    halt
