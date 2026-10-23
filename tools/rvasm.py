#!/usr/bin/env python3
"""Tiny assembler + reference simulator for the project's RV32I subset.

Usage:  python3 tools/rvasm.py prog.s OUT_DIR

Writes OUT_DIR/<name>.hex       256 instruction words, NOP-padded (for $readmemh)
       OUT_DIR/<name>.expected  32 register values then 256 data-memory words,
                                the architectural state after the program halts.
       OUT_DIR/<name>.lst       "pc<TAB>source" listing (used by tools/figures.py).

Supported: add sub and or xor addi andi ori xori lw sw beq bne nop halt
  - registers: x0..x31 or "zero"
  - labels: "name:"; comments start with '#'
  - halt = "beq x0, x0, 0" (jumps to itself); simulation stops when it is fetched.
"""
import os
import re
import sys

R_TYPE = {"add": (0x00, 0b000), "sub": (0x20, 0b000), "and": (0x00, 0b111),
          "or": (0x00, 0b110), "xor": (0x00, 0b100)}
I_ALU = {"addi": 0b000, "andi": 0b111, "ori": 0b110, "xori": 0b100}
BRANCH = {"beq": 0b000, "bne": 0b001}
HALT_WORD = 0x00000063
MEM_WORDS = 256
MAX_STEPS = 100000


def reg(tok):
    tok = tok.strip()
    if tok == "zero":
        return 0
    m = re.fullmatch(r"x(\d+)", tok)
    if not m or int(m.group(1)) > 31:
        raise ValueError(f"bad register '{tok}'")
    return int(m.group(1))


def imm(tok, bits):
    v = int(tok.strip(), 0)
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    if not lo <= v <= hi:
        raise ValueError(f"immediate {v} does not fit in {bits} bits")
    return v


def parse(path):
    """Return a list of (mnemonic, operands, line_no, text) and a label -> address map."""
    insts, labels = [], {}
    with open(path) as f:
        for n, line in enumerate(f, 1):
            line = line.split("#")[0].strip()
            while ":" in line:
                label, line = line.split(":", 1)
                labels[label.strip()] = 4 * len(insts)
                line = line.strip()
            if not line:
                continue
            parts = line.replace(",", " ").split(None, 1)
            ops = parts[1].replace(",", " ").split() if len(parts) > 1 else []
            insts.append((parts[0].lower(), ops, n, " ".join(line.split())))
    return insts, labels


def encode(mn, ops, pc, labels):
    """Encode one instruction into a 32-bit word."""
    if mn == "nop":
        mn, ops = "addi", ["x0", "x0", "0"]
    if mn == "halt":
        return HALT_WORD
    if mn in R_TYPE:
        f7, f3 = R_TYPE[mn]
        rd, rs1, rs2 = map(reg, ops)
        return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33
    if mn in I_ALU:
        rd, rs1, v = reg(ops[0]), reg(ops[1]), imm(ops[2], 12)
        return ((v & 0xFFF) << 20) | (rs1 << 15) | (I_ALU[mn] << 12) | (rd << 7) | 0x13
    if mn in ("lw", "sw"):
        m = re.fullmatch(r"(-?\w+)\((\w+)\)", ops[1].replace(" ", ""))
        if not m:
            raise ValueError(f"expected offset(reg), got '{ops[1]}'")
        v, base, r = imm(m.group(1), 12), reg(m.group(2)), reg(ops[0])
        if mn == "lw":
            return ((v & 0xFFF) << 20) | (base << 15) | (0b010 << 12) | (r << 7) | 0x03
        return (((v >> 5) & 0x7F) << 25) | (r << 20) | (base << 15) | (0b010 << 12) \
            | ((v & 0x1F) << 7) | 0x23
    if mn in BRANCH:
        rs1, rs2 = reg(ops[0]), reg(ops[1])
        target = ops[2]
        off = labels[target] - pc if target in labels else int(target, 0)
        v = imm(str(off), 13)
        if v % 2:
            raise ValueError("branch offset must be even")
        return (((v >> 12) & 1) << 31) | (((v >> 5) & 0x3F) << 25) | (rs2 << 20) \
            | (rs1 << 15) | (BRANCH[mn] << 12) | (((v >> 1) & 0xF) << 8) \
            | (((v >> 11) & 1) << 7) | 0x63
    raise ValueError(f"unknown instruction '{mn}'")


def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def simulate(words):
    """Run the program on an ISA-level model; return (regs, mem, instructions_retired)."""
    regs, mem, pc, retired = [0] * 32, [0] * MEM_WORDS, 0, 0
    for _ in range(MAX_STEPS):
        w = words[pc // 4] if pc // 4 < len(words) else 0x13
        if w == HALT_WORD:
            return regs, mem, retired
        op, rd, f3 = w & 0x7F, (w >> 7) & 0x1F, (w >> 12) & 7
        rs1, rs2, f7 = (w >> 15) & 0x1F, (w >> 20) & 0x1F, w >> 25
        a, b = regs[rs1], regs[rs2]
        nxt, wr = pc + 4, None
        if op == 0x33:
            if f3 == 0:
                wr = a - b if f7 & 0x20 else a + b
            else:
                wr = {7: a & b, 6: a | b, 4: a ^ b}.get(f3, a + b)
        elif op == 0x13:
            i = sext(w >> 20, 12) & 0xFFFFFFFF
            wr = {7: a & i, 6: a | i, 4: a ^ i}.get(f3, a + i)
        elif op == 0x03:
            wr = mem[((a + sext(w >> 20, 12)) >> 2) % MEM_WORDS]
        elif op == 0x23:
            mem[((a + sext(((w >> 25) << 5) | ((w >> 7) & 0x1F), 12)) >> 2) % MEM_WORDS] = b
        elif op == 0x63:
            off = sext((((w >> 31) & 1) << 12) | (((w >> 7) & 1) << 11)
                       | (((w >> 25) & 0x3F) << 5) | (((w >> 8) & 0xF) << 1), 13)
            if (f3 == 0 and a == b) or (f3 == 1 and a != b):
                nxt = pc + off
        if wr is not None and rd != 0:
            regs[rd] = wr & 0xFFFFFFFF
        pc = nxt & 0xFFFFFFFF
        retired += 1
    raise RuntimeError("program did not reach 'halt'")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, out_dir = sys.argv[1], sys.argv[2]
    insts, labels = parse(src)
    words = []
    for i, (mn, ops, n, _) in enumerate(insts):
        try:
            words.append(encode(mn, ops, 4 * i, labels))
        except (ValueError, KeyError, IndexError) as e:
            sys.exit(f"{src}:{n}: {e}")
    if len(words) > 256:
        sys.exit(f"{src}: program has {len(words)} words; instruction memory holds 256")
    regs, mem, retired = simulate(words)
    name = os.path.splitext(os.path.basename(src))[0]
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, name + ".hex"), "w") as f:
        # pad with NOPs to the full 256-word instruction memory
        f.write("".join(f"{w:08x}\n" for w in words + [0x13] * (256 - len(words))))
    with open(os.path.join(out_dir, name + ".expected"), "w") as f:
        f.write("".join(f"{v:08x}\n" for v in regs + mem))
    with open(os.path.join(out_dir, name + ".lst"), "w") as f:
        f.write("".join(f"{4 * i:x}\t{text}\n" for i, (_, _, _, text) in enumerate(insts)))
    print(f"{name}: {len(words)} words, {retired} instructions retired (ISA model)")


if __name__ == "__main__":
    main()
