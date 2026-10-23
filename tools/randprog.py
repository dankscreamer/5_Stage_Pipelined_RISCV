#!/usr/bin/env python3
"""Generate random test programs that stress pipeline hazards.

Usage:  python3 tools/randprog.py OUT_DIR COUNT [LENGTH] [SEED]

Programs use only x1..x7 as destinations, so back-to-back dependencies (forwarding,
load-use stalls, store-data forwarding) are very frequent. x8 holds a fixed base address
for loads/stores so every access stays inside data memory. Branches only jump forward,
so every program terminates.
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


def program(rng, length):
    lines = ["    addi x8, x0, 128   # base address, never overwritten"]
    for i in range(length):
        lines.append(f"L{i}:")
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
            target = min(i + rng.randint(1, 4), length)
            lines.append(f"    {rng.choice(['beq', 'bne'])} {reg(rng)}, {reg(rng)}, L{target}")
    lines.append(f"L{length}:")
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
