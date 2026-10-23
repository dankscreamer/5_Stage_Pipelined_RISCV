# BENCHMARK: copy 48 words from 0x000 to 0x200 (loop, 1 word per iteration).
# Each store uses the value just loaded, so this pipeline stalls 1 cycle per word.

    addi x1, x0, 0
    addi x2, x0, 7
    addi x3, x0, 192     # 48 words
fill:
    sw   x2, 0(x1)
    xori x2, x2, 0x155
    addi x2, x2, 9
    addi x1, x1, 4
    bne  x1, x3, fill
    addi x1, x0, 0
copy:
    lw   x5, 0(x1)
    sw   x5, 512(x1)
    addi x1, x1, 4
    bne  x1, x3, copy
    halt
