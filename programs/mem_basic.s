# Stores and loads with positive, zero and negative offsets.
    addi x1, x0, 64      # base address
    addi x2, x0, 111
    addi x3, x0, -7
    sw   x2, 0(x1)
    sw   x3, 4(x1)
    sw   x2, -4(x1)
    lw   x4, 0(x1)       # 111
    lw   x5, 4(x1)       # -7
    lw   x6, -4(x1)      # 111
    add  x7, x4, x5      # 104
    sw   x7, 8(x1)
    lw   x8, 8(x1)       # 104
    sw   x0, 12(x1)      # store zero
    lw   x9, 12(x1)
    halt
