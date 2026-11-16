# Test Program 2: Arithmetic and Logic Instructions (program_arithmetic.hex)
# Architecture: RV32I Subset
# Target: Verification of ADDI, ADD, SUB, AND, OR, XOR

.text
.globl _start
_start:
    # 0x00: 00500093
    addi x1, x0, 5       # x1 = 5

    # 0x04: 00A00113
    addi x2, x0, 10      # x2 = 10 (0x0A)

    # 0x08: 002081B3
    add  x3, x1, x2      # x3 = x1 + x2 = 15 (0x0F)

    # 0x0C: 40208233
    sub  x4, x1, x2      # x4 = x1 - x2 = -5 (0xFFFFFFFB)

    # 0x10: 0020F2B3
    and  x5, x1, x2      # x5 = x1 & x2 = 5 & 10 = 0 (0x00)

    # 0x14: 0020E333
    or   x6, x1, x2      # x6 = x1 | x2 = 5 | 10 = 15 (0x0F)

    # 0x18: 0020C3B3
    xor  x7, x1, x2      # x7 = x1 ^ x2 = 5 ^ 10 = 15 (0x0F)

    # 0x1C: 00000013
    addi x0, x0, 0       # NOP
