#!/usr/bin/env python3
"""Generate random test programs that stress pipeline hazards.

Usage:  python3 tools/randprog.py OUT_DIR COUNT [LENGTH] [SEED]

Programs use only x1..x7 as destinations, so back-to-back dependencies (forwarding,
load-use stalls, store-data forwarding) are very frequent. x8 holds a fixed base address
for loads/stores so every access stays inside data memory. Programs mix straight-line
blocks with counted loops (x9 = counter): the loop's backward branch exercises branch
prediction, half of the time through a load-use stall on the branch (x10 = reloaded
counter). Branches inside a block only jump forward, so every program terminates.
"""
import os
import random
import sys

R_OPS = ["add", "sub", "and", "or", "xor"]
I_OPS = ["addi", "andi", "ori", "xori"]


def reg(rng):
    return f"x{rng.randint(0, 7)}"  # include x0 sometimes


def dst(rng):
    return f"x{rng.randint(1, 7)}"


def straight(rng, n, prefix):
    """n random instructions; branches jump forward within this block (to <prefix>_end)."""
    lines = []
    for i in range(n):
        lines.append(f"{prefix}_{i}:")
        kind = rng.choices(["r", "i", "lw", "sw", "br"], weights=[30, 25, 18, 12, 15])[0]
        if kind == "r":
            lines.append(f"    {rng.choice(R_OPS)} {dst(rng)}, {reg(rng)}, {reg(rng)}")
        elif kind == "i":
            lines.append(f"    {rng.choice(I_OPS)} {dst(rng)}, {reg(rng)}, {rng.randint(-2048, 2047)}")
        elif kind == "lw":
            lines.append(f"    lw {dst(rng)}, {4 * rng.randint(-32, 31)}(x8)")
        elif kind == "sw":
            lines.append(f"    sw {reg(rng)}, {4 * rng.randint(-32, 31)}(x8)")
        else:
            j = i + rng.randint(1, 4)
            target = f"{prefix}_{j}" if j < n else f"{prefix}_end"
            lines.append(f"    {rng.choice(['beq', 'bne'])} {reg(rng)}, {reg(rng)}, {target}")
    lines.append(f"{prefix}_end:")
    return lines


def program(rng, length):
    """Straight-line blocks and counted loops (x9 = loop counter, never a random destination)."""
    lines = ["    addi x8, x0, 128   # base address, never overwritten"]
    emitted, block = 0, 0
    while emitted < length:
        n = rng.randint(3, 10)
        if rng.random() < 0.4:
            # counted loop: backward branch taken (trips - 1) times, then falls through
            trips = rng.randint(1, 6)
            lines.append(f"    addi x9, x0, {trips}")
            lines.append(f"B{block}_top:")
            lines += straight(rng, n, f"B{block}")
            lines.append("    addi x9, x9, -1")
            if rng.random() < 0.5:
                # the branch reads x9 right after it is written: forwarding into EX
                lines.append(f"    bne x9, x0, B{block}_top")
            else:
                # the branch reads a just-loaded copy: load-use stall while the branch
                # sits in ID (address 0x100 is outside the random loads/stores' range)
                lines.append("    sw x9, 128(x8)")
                lines.append("    lw x10, 128(x8)")
                lines.append(f"    bne x10, x0, B{block}_top")
            emitted += n + 3
        else:
            lines += straight(rng, n, f"B{block}")
            emitted += n
        block += 1
    lines.append("    halt")
    return "\n".join(lines) + "\n"


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out_dir, count = sys.argv[1], int(sys.argv[2])
    length = int(sys.argv[3]) if len(sys.argv) > 3 else 60
    seed = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    rng = random.Random(seed)
    os.makedirs(out_dir, exist_ok=True)
    for n in range(count):
        with open(os.path.join(out_dir, f"rand{n:03d}.s"), "w") as f:
            f.write(program(rng, length))
    print(f"wrote {count} programs of {length} instructions to {out_dir} (seed {seed})")


if __name__ == "__main__":
    main()
