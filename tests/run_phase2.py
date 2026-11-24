#!/usr/bin/env python3
"""Check both cores against architectural results and count simulated cycles."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / ".build" / "phase2"
NOP = 0x00000013
MASK = 0xFFFFFFFF


def addi(rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (rd << 7) | 0x13


def op(rd, rs1, rs2, funct3=0, subtract=False):
    return ((0x20 if subtract else 0) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x33


def lw(rd, rs1, offset=0):
    return ((offset & 0xFFF) << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 3


def sw(rs2, rs1=0, offset=0):
    imm = offset & 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 31) << 7) | 0x23


def branch(rs1, rs2, offset, funct3=0):
    imm = offset & 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 63) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (((imm >> 1) & 15) << 8) | (((imm >> 11) & 1) << 7) | 0x63


def spaced(words):
    result = []
    for word in words:
        result += [word, NOP, NOP, NOP]
    return result[:-3]


def read_hex(name):
    return [int(word, 16) for word in (ROOT / name).read_text().split()]


def branch_program(a, b, funct3, pipeline):
    setup = [addi(1, 0, a), addi(2, 0, b)]
    if pipeline:
        setup += [NOP] * 3
    # Both younger instructions have side effects; both must be flushed.
    return setup + [branch(1, 2, 12, funct3), sw(1), addi(3, 0, 99), addi(4, 0, 10)]


def cases():
    chain = [addi(1, 0, 5), addi(1, 1, 7), op(2, 1, 1),
             sw(2), lw(3, 0), op(4, 3, 1)]
    offsets = [addi(1, 0, 16), addi(2, 0, 42), sw(2, 1, -4), lw(3, 1, -4)]
    loop_single = [addi(1, 0, 3), addi(2, 0, 1), op(1, 1, 2, subtract=True),
                   branch(1, 0, -4, 1), addi(4, 0, 10)]
    loop_pipeline = [addi(1, 0, 3), addi(2, 0, 1)] + [NOP] * 3
    loop_pipeline += [op(1, 1, 2, subtract=True)] + [NOP] * 3
    loop_pipeline += [branch(1, 0, -16, 1), addi(4, 0, 10)]
    independent = [addi(rd, 0, rd) for rd in range(1, 17)]
    return {
        "arithmetic": (read_hex("program_arithmetic.hex")[:7], read_hex("program_phase2_arithmetic.hex")),
        "memory": (read_hex("program_memory.hex")[:3], read_hex("program_phase2_memory.hex")),
        "branch": (read_hex("program_branch.hex")[:5], read_hex("program_phase2_branch.hex")),
        "beq_taken_flush": (branch_program(5, 5, 0, False), branch_program(5, 5, 0, True)),
        "beq_not_taken": (branch_program(5, 6, 0, False), branch_program(5, 6, 0, True)),
        "bne_taken_flush": (branch_program(5, 6, 1, False), branch_program(5, 6, 1, True)),
        "bne_not_taken": (branch_program(5, 5, 1, False), branch_program(5, 5, 1, True)),
        "backward_branch": (loop_single, loop_pipeline),
        "dependent_chain": (chain, spaced(chain)),
        "memory_offsets": (offsets, spaced(offsets)),
        "x0": ([addi(0, 0, 7), addi(1, 0, 5)], [addi(0, 0, 7), addi(1, 0, 5)]),
        "independent_16": (independent, independent),
        "reset_store": ([sw(0), addi(1, 0, 1)], [sw(0), addi(1, 0, 1)]),
    }


def signed(value, bits):
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def reference(words):
    """Small ISA model, independent of RTL controls and pipeline timing."""
    regs, memory, trace = [0] * 32, [0] * 64, []
    pc = taken = useful = 0
    for _ in range(150):
        assert pc % 4 == 0 and 0 <= pc // 4 < len(words), "Reference PC out of program"
        word = words[pc // 4]
        opcode, rd = word & 127, (word >> 7) & 31
        rs1, rs2, funct3 = (word >> 15) & 31, (word >> 20) & 31, (word >> 12) & 7
        next_pc, value = pc + 4, None
        if opcode == 0x13 and funct3 == 0:
            value = regs[rs1] + signed(word >> 20, 12)
        elif opcode == 0x33:
            a, b = regs[rs1], regs[rs2]
            if funct3 == 0:
                value = a - b if (word >> 30) & 1 else a + b
            elif funct3 == 7:
                value = a & b
            elif funct3 == 6:
                value = a | b
            elif funct3 == 4:
                value = a ^ b
            else:
                raise AssertionError("Unsupported reference ALU operation")
        elif opcode in (3, 0x23) and funct3 == 2:
            imm = word >> 20 if opcode == 3 else ((word >> 25) << 5) | ((word >> 7) & 31)
            address = (regs[rs1] + signed(imm, 12)) & MASK
            assert address % 4 == 0 and address < 256
            if opcode == 3:
                value = memory[address // 4]
            else:
                memory[address // 4] = regs[rs2]
        elif opcode == 0x63 and funct3 in (0, 1):
            imm = (((word >> 31) & 1) << 12) | (((word >> 7) & 1) << 11) | (((word >> 25) & 63) << 5) | (((word >> 8) & 15) << 1)
            condition = regs[rs1] == regs[rs2]
            if condition == (funct3 == 0):
                next_pc = pc + signed(imm, 13)
                taken += 1
        else:
            raise AssertionError(f"Unsupported reference instruction {word:08x}")
        if value is not None and rd:
            regs[rd] = value & MASK
        trace.append(pc)
        useful += word != NOP
        if pc == (len(words) - 1) * 4:
            return regs, memory, trace, taken, useful
        pc = next_pc
    raise AssertionError("Reference program did not finish")


def command(args):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        raise AssertionError(f"Command failed: {' '.join(map(str, args))}\n{result.stdout}{result.stderr}")
    return result.stdout


def simulate(name, core, words):
    path = BUILD / f"{name}_{core}.hex"
    assert len(words) <= 64
    path.write_text("".join(f"{word:08x}\n" for word in words + [NOP] * (64 - len(words))))
    output = command([os.environ.get("VVP", "vvp"), str(BUILD / f"{core}.out"),
                      f"+PROGRAM={path}", f"+STOP_PC={(len(words) - 1) * 4}",
                      f"+VCD={BUILD / (name + '_' + core + '.vcd')}"])
    (BUILD / f"{name}_{core}.log").write_text(output)
    regs, memory, trace, cycles = {}, {}, [], None
    for line in output.splitlines():
        parts = line.split()
        if parts and parts[0] in ("REG", "MEM"):
            target = regs if parts[0] == "REG" else memory
            target[int(parts[1])] = int(parts[2], 16)
        elif parts and parts[0] == "RETIRE":
            trace.append(int(parts[2], 16))
        elif parts and parts[0] == "CYCLES":
            cycles = int(parts[1])
    assert len(regs) == 32 and len(memory) == 64 and cycles is not None, output
    return list(regs.values()), list(memory.values()), trace, cycles


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=list(cases()))
    parser.add_argument("--core", choices=["single", "pipeline", "both"], default="both")
    parser.add_argument("--report", type=Path, default=BUILD / "performance.md")
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    cores = ["single", "pipeline"] if args.core == "both" else [args.core]
    for core in cores:
        options = ["-DPIPELINED"] if core == "pipeline" else []
        command([os.environ.get("IVERILOG", "iverilog"), "-g2012", "-s", "tb_phase2", *options,
                 "-o", str(BUILD / f"{core}.out"), "modules/tb_phase2.v"])
    rows = []
    selected = cases()
    if args.case:
        selected = {args.case: selected[args.case]}
    for name, programs in selected.items():
        cycles_by_core = {}
        for core in cores:
            words = programs[core == "pipeline"]
            expected_regs, expected_mem, expected_trace, taken, useful = reference(words)
            regs, memory, trace, cycles = simulate(name, core, words)
            assert regs == expected_regs, f"{name}/{core}: register mismatch: {regs} != {expected_regs}"
            assert memory == expected_mem, f"{name}/{core}: memory mismatch"
            assert trace == expected_trace, f"{name}/{core}: retirement PC mismatch: {trace} != {expected_trace}"
            expected_cycles = len(expected_trace) + (4 + 2 * taken if core == "pipeline" else 0)
            assert cycles == expected_cycles, f"{name}/{core}: {cycles} cycles != {expected_cycles}"
            cycles_by_core[core] = cycles
            print(f"PASS {name:20} {core:8} cycles={cycles:2} useful={useful:2} retired={len(trace):2} taken={taken}")
        if len(cores) == 2:
            # NOP scheduling must preserve the final architectural state.
            assert reference(programs[0])[:2] == reference(programs[1])[:2], name
            single, pipeline = cycles_by_core["single"], cycles_by_core["pipeline"]
            rows.append(f"| {name} | {useful} | {single} | {pipeline} | {single * 10} | {pipeline * 10} | {single / pipeline:.3f} | {pipeline / single:.3f} |")
    if "pipeline" in cores and not args.case:
        # Two NOPs still sample ID at the writer's WB edge: no bypass exists.
        unsafe = [addi(1, 0, 5), NOP, NOP, op(2, 1, 1)]
        regs, _, _, _ = simulate("unscheduled_dependency", "pipeline", unsafe)
        assert regs[1] == 5 and regs[2] == 0, "Expected old operand without a WB-to-ID bypass"
        print("PASS limitation demo: two NOPs give x2=0; three are required for x2=10")
    if rows:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(
            "# Phase 2 measured simulation performance\n\n"
            "Generated by `python3 tests/run_phase2.py --report docs/phase2_performance.md`.\n\n"
            "Both cores use a 10 ns simulation clock. Execution time is counted active cycles multiplied by 10 ns, through the final useful instruction's WB edge (the completion edge for Phase 1). "
            "Reset cycles and the 1 ns state-observation delay are excluded. This is whole-cycle accounting, not final timestamp minus reset-release timestamp.\n\n"
            "Single-cycle programs contain no scheduling NOPs. Pipeline programs explicitly space dependencies. Useful instructions exclude NOPs and include executed branches/stores. "
            "Cycles include pipeline fill/drain, scheduling NOPs, and taken-branch flushes.\n\n"
            "| Program | Useful instructions | Single cycles | Pipeline cycles | Single time (ns) | Pipeline time (ns) | Speedup at equal clock | Clock-frequency ratio needed to break even |\n"
            "|---|---:|---:|---:|---:|---:|---:|---:|\n" + "\n".join(rows) +
            "\n\nSpeedup = single time / pipeline time. A value below 1 means the pipeline is slower at the equal test clock. "
            "To beat the baseline, pipeline frequency must exceed single-cycle frequency multiplied by the last column. "
            "These are simulated cycle/time measurements, not measured maximum hardware frequencies. No cell library, synthesis timing, or physical implementation is provided.\n\n"
            "All rows passed checks of all 32 register slots, all 64 data-memory words, exact retirement PC sequence, and expected cycle count. "
            "Test fixtures initialize registers/RAM to zero; hardware reset does not clear those arrays.\n"
        )
        print(f"Report: {args.report}")


if __name__ == "__main__":
    main()
