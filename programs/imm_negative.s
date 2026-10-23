# Negative / large immediates. "addi x1, x0, -1" has instruction bit 30 set and
# used to decode as SUB in alu_control.
    addi x1, x0, -1      # 0xFFFFFFFF
    addi x2, x0, -2048   # most negative 12-bit immediate
    addi x3, x0, 2047    # most positive
    addi x4, x1, -1      # -2
    andi x5, x1, 0x0F0   # 0xF0
    ori  x6, x0, -256    # 0xFFFFFF00
    xori x7, x1, 0x555   # ~0x555
    xori x8, x7, -1      # back to 0x555
    sub  x9, x0, x3      # -2047
    add  x10, x2, x3     # -1
    addi x0, x0, 99      # writes to x0 must be ignored
    add  x11, x0, x0     # 0
    halt
