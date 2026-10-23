# Same program as modules/program.hex, plus a halt.
    addi x1, x0, 5
    addi x2, x0, 10
    add  x3, x1, x2      # 15
    sub  x4, x1, x2      # -5
    and  x5, x1, x2      # 0
    or   x6, x1, x2      # 15
    xor  x7, x1, x2      # 15
    nop
    halt
