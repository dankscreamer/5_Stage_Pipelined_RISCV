# Short program for the report figures: shows every hazard case in ~10 instructions.
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2      # x2 forwarded from EX/MEM, x1 from MEM/WB
    sw   x3, 0(x0)       # store data x3 forwarded from EX/MEM
    lw   x4, 0(x0)
    add  x5, x4, x1      # load-use: 1 stall, then x4 forwarded from MEM/WB
    beq  x5, x5, skip    # taken: the next two fetched instructions are flushed
    addi x6, x0, 1       # flushed
    addi x7, x0, 1       # flushed
skip:
    sub  x8, x5, x3
    halt
