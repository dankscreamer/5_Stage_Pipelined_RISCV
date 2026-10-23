# First 12 Fibonacci numbers written to memory from address 0x40.
    addi x1, x0, 0       # f(n-2)
    addi x2, x0, 1       # f(n-1)
    addi x3, x0, 64      # pointer
    addi x4, x0, 12      # count
    addi x5, x0, 0       # i
loop:
    sw   x1, 0(x3)
    add  x6, x1, x2
    add  x1, x2, x0
    add  x2, x6, x0
    addi x3, x3, 4
    addi x5, x5, 1
    bne  x5, x4, loop
    halt
