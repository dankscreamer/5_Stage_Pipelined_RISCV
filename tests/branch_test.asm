# Test Program 1: Conditional Branch Verification (program.hex)
# Architecture: RV32I Subset
# Target: Verification of BEQ instruction and PC redirection

.text
.globl _start
_start:
    # 0x00: 00500093
    addi x1, x0, 5       # x1 = 5

    # 0x04: 00500113
    addi x2, x0, 5       # x2 = 5

    # 0x08: 00208463
    beq  x1, x2, target  # Taken branch: offset +8 bytes -> PC 0x10

    # 0x0C: 06300193
    addi x3, x0, 99      # Bypassed instruction (should not execute)

target:
    # 0x10: 00A00213
    addi x4, x0, 10      # Branch target executed: x4 = 10

    # 0x14: 00000013
    addi x0, x0, 0       # NOP

    # 0x18: 00000013
    addi x0, x0, 0       # NOP

    # 0x1C: 00000013
    addi x0, x0, 0       # NOP
