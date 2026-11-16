# Test Program 3: Memory Load and Store Instructions (program_memory.hex)
# Architecture: RV32I Subset
# Target: Verification of SW (Store Word) and LW (Load Word)

.text
.globl _start
_start:
    # 0x00: 02A00093
    addi x1, x0, 42      # x1 = 42 (0x0000002A)

    # 0x04: 00102023
    sw   x1, 0(x0)       # Store word: Memory[0] = x1 (42)

    # 0x08: 00002103
    lw   x2, 0(x0)       # Load word: x2 = Memory[0] (should be 42)

    # 0x0C: 00000013
    addi x0, x0, 0       # NOP

    # 0x10: 00000013
    addi x0, x0, 0       # NOP

    # 0x14: 00000013
    addi x0, x0, 0       # NOP

    # 0x18: 00000013
    addi x0, x0, 0       # NOP

    # 0x1C: 00000013
    addi x0, x0, 0       # NOP
