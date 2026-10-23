# BENCHMARK: same work as bench_loaduse, but the code is scheduled (two loads issued
# before their uses), the way a compiler would, so no load-use stalls occur.
    addi x1, x0, 0       # pointer
    addi x2, x0, 3       # value
    addi x3, x0, 128     # end pointer (32 words)
fill:
    sw   x2, 0(x1)
    addi x2, x2, 5
    addi x1, x1, 4
    bne  x1, x3, fill
    addi x10, x0, 0      # sum
    lw   x5, 0(x0)
    lw   x6, 4(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 8(x0)
    lw   x6, 12(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 16(x0)
    lw   x6, 20(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 24(x0)
    lw   x6, 28(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 32(x0)
    lw   x6, 36(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 40(x0)
    lw   x6, 44(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 48(x0)
    lw   x6, 52(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 56(x0)
    lw   x6, 60(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 64(x0)
    lw   x6, 68(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 72(x0)
    lw   x6, 76(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 80(x0)
    lw   x6, 84(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 88(x0)
    lw   x6, 92(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 96(x0)
    lw   x6, 100(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 104(x0)
    lw   x6, 108(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 112(x0)
    lw   x6, 116(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    lw   x5, 120(x0)
    lw   x6, 124(x0)
    add  x10, x10, x5    # x5 loaded 2 instructions ago -> forwarded, no stall
    add  x10, x10, x6
    sw   x10, 512(x0)
    halt
