#!/usr/bin/env python3
"""Synthesise and place-and-route each CPU for a Lattice iCE40 HX8K and collect results.

Usage:  python3 tools/synth.py BUILD_DIR RESULTS_DIR [SEEDS]

Flow: Yosys (synth_ice40) -> nextpnr-ice40 (--hx8k, ct256), SEEDS placement seeds per
design (default 3); the median Fmax is reported. Writes RESULTS_DIR/synth.json and
RESULTS_DIR/synth.md, and keeps the full logs in BUILD_DIR/synth/.

Instruction and data memories are 32 words each here (IMEM_DEPTH/DMEM_DEPTH) so the
single-cycle CPU, whose asynchronous-read memories must be built from logic cells, fits
on the device. The same size is used for every design. (A pipelined build with block RAM
disabled was also tried; it needs ~98 % of the HX8K's logic cells and fails placement.)
"""
import json
import os
import re
import statistics
import subprocess
import sys

DEPTH = 32
DEVICE = "iCE40 HX8K (ct256)"
DESIGNS = {
    # key: (top module, extra chparam, synth_ice40 options, description)
    "single": ("single_cycle_top", "", "", "Single-cycle"),
    "fwd": ("pipeline_top", "-set FORWARDING 1", "", "Pipelined, forwarding"),
    "nofwd": ("pipeline_top", "-set FORWARDING 0", "", "Pipelined, no forwarding"),
    "bp1": ("pipeline_top", "-set FORWARDING 1 -set BRANCH_PRED 1", "",
            "Pipelined, forwarding, static prediction"),
    "bp2": ("pipeline_top", "-set FORWARDING 1 -set BRANCH_PRED 2", "",
            "Pipelined, forwarding, dynamic prediction (8-entry BTB)"),
}
TOPS = ("modules/single_cycle_top.v", "modules/pipeline_top.v")


def sh(cmd, log):
    """Run a command, saving combined output to log; return the output."""
    p = subprocess.run(cmd, capture_output=True, text=True)
    with open(log, "w") as f:
        f.write(p.stdout + p.stderr)
    if p.returncode != 0:
        sys.exit(f"command failed (see {log}): {' '.join(cmd)}")
    return p.stdout + p.stderr


def cell_counts(stat_text):
    """Sum cell types from Yosys `stat` output."""
    counts = {}
    for m in re.finditer(r"^\s+(\d+)\s+(SB_\w+)\s*$", stat_text, re.M):
        counts[m.group(2)] = counts.get(m.group(2), 0) + int(m.group(1))
    return counts


def critical_path(log):
    """Return (start, end) cell pins of the clock-domain critical path in a nextpnr log."""
    start = log.find("Critical path report for clock")
    if start < 0:
        return ("?", "?")
    end = min(i for i in (log.find("Critical path report for cross-domain", start),
                          log.find("Max frequency", start), len(log)) if i >= 0)
    cells = re.findall(r"Source (\S+)", log[start:end])
    return (cells[0], cells[-1]) if cells else ("?", "?")


def nextpnr_version():
    """nextpnr's own --version is empty in some builds; fall back to the package manager."""
    out = subprocess.run(["nextpnr-ice40", "--version"], capture_output=True, text=True)
    m = re.search(r"Version ([^)\s]+)", out.stdout + out.stderr)
    if m:
        return f"nextpnr-ice40 {m.group(1)}"
    brew = subprocess.run(["brew", "list", "--versions", "nextpnr-ice40"], capture_output=True, text=True)
    return brew.stdout.strip() or "nextpnr-ice40"


def main():
    build, results = sys.argv[1], sys.argv[2]
    seeds = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    out_dir = os.path.join(build, "synth")
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(results, exist_ok=True)
    rtl = sorted(os.path.join("modules", f) for f in os.listdir("modules")
                 if f.endswith(".v") and os.path.join("modules", f) not in TOPS)

    designs = {}
    for key, (top, params, opts, desc) in DESIGNS.items():
        json_path = os.path.join(out_dir, f"{key}.json")
        stat_path = os.path.join(out_dir, f"{key}_stat.txt")
        script = (f"read_verilog -defer {' '.join(rtl)} modules/{top}.v; "
                  f"chparam -set IMEM_DEPTH {DEPTH} -set DMEM_DEPTH {DEPTH} {params} {top}; "
                  f"synth_ice40 {opts} -top {top} -json {json_path}; tee -q -o {stat_path} stat")
        sh(["yosys", "-q", "-p", script], os.path.join(out_dir, f"{key}_yosys.log"))
        with open(stat_path) as f:
            cells = cell_counts(f.read())

        runs = []
        for seed in range(1, seeds + 1):
            report = os.path.join(out_dir, f"{key}_seed{seed}.json")
            log_path = os.path.join(out_dir, f"{key}_seed{seed}.log")
            log = sh(["nextpnr-ice40", "--hx8k", "--package", "ct256", "--json", json_path,
                      "--freq", "100", "--timing-allow-fail", "--seed", str(seed),
                      "--report", report], log_path)
            with open(report) as f:
                rep = json.load(f)
            fmax = next(v["achieved"] for k, v in rep["fmax"].items() if "clk" in k)
            runs.append({"seed": seed, "fmax_mhz": fmax, "log": log_path,
                         "critical_path": critical_path(log), "util": rep["utilization"]})
        runs.sort(key=lambda r: r["fmax_mhz"])
        median = runs[len(runs) // 2]
        util = median["util"]
        ffs = sum(v for k, v in cells.items() if k.startswith("SB_DFF"))
        designs[key] = {
            "description": desc,
            "fmax_mhz": statistics.median(r["fmax_mhz"] for r in runs),
            "fmax_all_seeds": [round(r["fmax_mhz"], 2) for r in sorted(runs, key=lambda r: r["seed"])],
            "logic_cells": util["ICESTORM_LC"]["used"],
            "luts": cells.get("SB_LUT4", 0),
            "flip_flops": ffs,
            "carry": cells.get("SB_CARRY", 0),
            "bram": util["ICESTORM_RAM"]["used"],
            "critical_path": median["critical_path"],
            "median_log": median["log"],
        }
        print(f"{key:11} {designs[key]['fmax_mhz']:6.2f} MHz  LC={designs[key]['logic_cells']:5}  "
              f"FF={ffs:5}  BRAM={designs[key]['bram']}  seeds={designs[key]['fmax_all_seeds']}")

    data = {"device": DEVICE, "imem_dmem_words": DEPTH, "seeds": seeds,
            "tools": {"yosys": subprocess.run(["yosys", "-V"], capture_output=True, text=True).stdout.strip(),
                      "nextpnr": nextpnr_version()},
            "designs": designs}
    with open(os.path.join(results, "synth.json"), "w") as f:
        json.dump(data, f, indent=1)

    md = ["# Synthesis results", "",
          f"Target: {DEVICE}. Flow: Yosys `synth_ice40` → nextpnr-ice40, {seeds} placement seeds per design,",
          f"median Fmax reported. Instruction and data memory: {DEPTH} words each (all designs).",
          f"Tools: {data['tools']['yosys']}; {data['tools']['nextpnr']}.", "",
          "| Design | Fmax (MHz, median) | Clock period (ns) | Logic cells | LUT4 | Flip-flops | Block RAMs | Fmax per seed |",
          "|---|--:|--:|--:|--:|--:|--:|---|"]
    for d in designs.values():
        md.append(f"| {d['description']} | **{d['fmax_mhz']:.1f}** | {1000 / d['fmax_mhz']:.1f} | {d['logic_cells']} "
                  f"| {d['luts']} | {d['flip_flops']} | {d['bram']} | {', '.join(map(str, d['fmax_all_seeds']))} |")
    md += ["", "Critical path (median seed), source → sink cell:", ""]
    for d in designs.values():
        md.append(f"- {d['description']}: `{d['critical_path'][0]}` → `{d['critical_path'][1]}`")
    with open(os.path.join(results, "synth.md"), "w") as f:
        f.write("\n".join(md) + "\n")
    print("\n".join(md))


if __name__ == "__main__":
    main()
