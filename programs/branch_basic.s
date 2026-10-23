# BEQ/BNE, taken and not taken, forward and backward.
    addi x1, x0, 3
    addi x2, x0, 3
    addi x3, x0, 4
    beq  x1, x2, skip1   # taken
    addi x10, x0, 1      # must be skipped
skip1:
    beq  x1, x3, bad     # not taken
    bne  x1, x3, skip2   # taken
    addi x11, x0, 1      # must be skipped
skip2:
    bne  x1, x2, bad     # not taken
    addi x4, x0, 0       # loop counter
    addi x5, x0, 5
loop:
    addi x4, x4, 1
    bne  x4, x5, loop    # backward branch, taken 4 times
    addi x6, x0, 42      # reached after loop
    halt
bad:
    addi x12, x0, -1     # must never run
    halt
