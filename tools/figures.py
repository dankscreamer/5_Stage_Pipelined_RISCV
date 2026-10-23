#!/usr/bin/env python3
"""Draw report figures as standalone SVG (no third-party packages).

  python3 tools/figures.py diagram PIPE LST OUT.svg "Title" [FIRST_CYCLE LAST_CYCLE]
      Classic pipeline diagram (instructions x cycles) from the +pipe=... output of
      tb_pipeline and the .lst listing written by tools/rvasm.py.

  python3 tools/figures.py wave VCD OUT.svg "Title" FIRST_CYCLE LAST_CYCLE SIGNAL[=label] ...
      Waveform of the given signals (dotted hierarchical names from the VCD).
      Cycle c is the clock period that starts at the c-th rising edge.
"""
import sys
from xml.sax.saxutils import escape

FONT = "font-family='Menlo, Consolas, monospace'"
STAGE_COLOR = {"IF": "#cfe2ff", "ID": "#d1e7dd", "EX": "#fff3cd", "MEM": "#f8d7da", "WB": "#e2d9f3"}
SRC = {1: "W", 2: "M"}  # forward source: 01 = MEM/WB, 10 = EX/MEM


def svg(width, height, body):
    return (f"<svg xmlns='http://www.w3.org/2000/svg' width='{width}' height='{height}' "
            f"viewBox='0 0 {width} {height}'>\n<rect width='100%' height='100%' fill='white'/>\n"
            + "\n".join(body) + "\n</svg>\n")


def text(x, y, s, size=12, anchor="start", color="#212529", weight="normal"):
    return (f"<text x='{x}' y='{y}' font-size='{size}' text-anchor='{anchor}' fill='{color}' "
            f"font-weight='{weight}' {FONT}>{escape(str(s))}</text>")


# --------------------------------------------------------------------------- diagram
def diagram(pipe_path, lst_path, out, title, first=None, last=None):
    """Pipeline diagram: one row per fetched instruction instance, one column per cycle."""
    listing = {}
    with open(lst_path) as f:
        for line in f:
            pc, src = line.rstrip("\n").split("\t", 1)
            listing[int(pc, 16)] = src
    halt_pcs = {pc for pc, s in listing.items() if s == "halt"}

    seq_pc, cells, events = {}, {}, {}
    with open(pipe_path) as f:
        for line in f:
            if line.startswith("#"):
                continue
            c, if_, id_, ex, mem, wb, stall, taken, fa, fb, *rest = line.split()
            idr = int(rest[0]) if rest else 0
            c = int(c)
            s_if, pc = if_.split(":")
            seq_pc[int(s_if)] = int(pc, 16)
            events[c] = (int(stall), int(taken), int(fa), int(fb), idr)
            for stage, s in (("IF", s_if), ("ID", id_), ("EX", ex), ("MEM", mem), ("WB", wb)):
                if int(s):
                    cells.setdefault(int(s), {})[c] = stage

    # keep instances up to the halt that completes (halts fetched on a wrong path get flushed);
    # this drops the halt's self-refetches
    first_halt = min((s for s in seq_pc if seq_pc[s] in halt_pcs and "WB" in cells.get(s, {}).values()),
                     default=max(seq_pc))
    cycles = sorted(events)
    first = first or cycles[0]
    last = last or max(c for s in cells if s <= first_halt for c in cells[s])
    rows = [s for s in sorted(cells) if s <= first_halt
            and any(first <= c <= last for c in cells[s])]

    cw, rh, label_w, top = 46, 24, 260, 64
    width = label_w + cw * (last - first + 1) + 20
    height = top + rh * len(rows) + 70
    body = [text(10, 22, title, 15, weight="bold")]
    for c in range(first, last + 1):
        x = label_w + cw * (c - first)
        body.append(text(x + cw / 2, top - 8, c, 11, "middle", "#6c757d"))
    for r, s in enumerate(rows):
        y = top + rh * r
        reached_wb = "WB" in cells[s].values()
        name = f"{seq_pc[s]:3x}  {listing.get(seq_pc[s], '?')}"
        body.append(text(10, y + 16, name, 12, color="#212529" if reached_wb else "#adb5bd"))
        prev = None
        for c in range(first, last + 1):
            stage = cells[s].get(c)
            if not stage:
                prev = None
                continue
            x = label_w + cw * (c - first)
            stalled = stage == prev  # same stage as last cycle: held by a stall
            fill = "#e9ecef" if stalled or not reached_wb else STAGE_COLOR[stage]
            body.append(f"<rect x='{x + 1}' y='{y + 2}' width='{cw - 2}' height='{rh - 4}' rx='3' "
                        f"fill='{fill}' stroke='#adb5bd' stroke-width='0.5'/>")
            label = "stall" if stalled and stage == "ID" else stage
            tags = []
            if stage == "EX" and reached_wb:
                _, _, fa, fb, _ = events[c]
                tags = [f"{op}←{SRC[v]}" for op, v in (("A", fa), ("B", fb)) if v in SRC]
            color = "#6c757d" if stalled or not reached_wb else "#212529"
            if tags:  # stage name on top, forwarding sources underneath, both inside the cell
                body.append(text(x + cw / 2, y + 11, label, 9, "middle", color))
                body.append(text(x + cw / 2, y + 19, " ".join(tags), 7, "middle", "#b02a37"))
            else:
                body.append(text(x + cw / 2, y + 16, label, 11, "middle", color))
            prev = stage
        if not reached_wb:
            xs = [label_w + cw * (c - first) for c in cells[s] if first <= c <= last]
            body.append(text(max(xs) + cw + 4, y + 16, "✕ flushed", 11, color="#b02a37"))
    # event row
    y = top + rh * len(rows) + 18
    for c in range(first, last + 1):
        stall, taken, _, _, idr = events.get(c, (0, 0, 0, 0, 0))
        x = label_w + cw * (c - first) + cw / 2
        if taken:
            body.append(text(x, y, "flush", 10, "middle", "#b02a37", "bold"))
        elif idr:
            body.append(text(x, y, "predict", 10, "middle", "#0d6efd", "bold"))
        elif stall:
            body.append(text(x, y, "stall", 10, "middle", "#6c757d", "bold"))
    body.append(text(10, y + 26, "A←M / B←W: ALU operand forwarded from EX/MEM (M) or MEM/WB (W). "
                     "Grey: stalled or flushed.", 10, color="#6c757d"))
    with open(out, "w") as f:
        f.write(svg(width, height, body))


# --------------------------------------------------------------------------- waveform
def parse_vcd(path, wanted):
    """Return {signal: [(time, value_str)]} for the requested dotted names."""
    ids, scope, changes, t = {}, [], {w: [] for w in wanted}, 0
    with open(path) as f:
        tokens = f.read().split()
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok == "$scope":
            scope.append(tokens[i + 2]); i += 4; continue
        if tok == "$upscope":
            scope.pop(); i += 2; continue
        if tok == "$var":
            code, name = tokens[i + 3], tokens[i + 4]
            full = ".".join(scope + [name])
            if full in changes:
                ids.setdefault(code, []).append(full)
            j = i
            while tokens[j] != "$end":
                j += 1
            i = j + 1; continue
        if tok.startswith("$"):
            if tok in ("$dumpvars", "$end", "$dumpall", "$dumpon", "$dumpoff"):
                i += 1; continue
            while tokens[i] != "$end":
                i += 1
            i += 1; continue
        if tok.startswith("#"):
            t = int(tok[1:]); i += 1; continue
        if tok[0] in "bBrR":
            val, code = tok[1:], tokens[i + 1]; i += 2
        else:
            val, code = tok[0], tok[1:]; i += 1
        for name in ids.get(code, []):
            changes[name].append((t, val))
    missing = [w for w, v in changes.items() if not v]
    if missing:
        sys.exit(f"signals not found in {path}: {missing}")
    return changes


def value_at(ch, t):
    v = ch[0][1]
    for tt, vv in ch:
        if tt > t:
            break
        v = vv
    return v


def fmt(v):
    if any(ch in v for ch in "xXzZ"):
        return "x"
    return f"{int(v, 2):x}"


def wave(vcd, out, title, first, last, specs):
    names = [s.split("=")[0] for s in specs]
    labels = [s.split("=")[1] if "=" in s else s.split(".")[-1] for s in specs]
    clk = next(n for n in names if n.endswith(".clk"))
    ch = parse_vcd(vcd, names)
    rises = [t for (t, v), (_, pv) in zip(ch[clk][1:], ch[clk]) if v == "1" and pv == "0"]
    last = min(last, len(rises) - 1)  # the simulation may end before the requested window
    t0, t1 = rises[first - 1], rises[last]
    period = rises[1] - rises[0]

    label_w, cw, rh, top = 150, 64, 30, 50
    width = label_w + cw * (last - first + 1) + 20
    height = top + rh * len(names) + 20
    sx = lambda t: label_w + (t - t0) / period * cw
    body = [text(10, 22, title, 15, weight="bold")]
    for c in range(first, last + 1):
        x = sx(rises[c - 1])
        body.append(f"<line x1='{x}' y1='{top - 14}' x2='{x}' y2='{height - 10}' stroke='#dee2e6'/>")
        body.append(text(x + cw / 2, top - 18, c, 10, "middle", "#6c757d"))
    for r, (name, label) in enumerate(zip(names, labels)):
        y = top + rh * r
        lo, hi = y + rh - 8, y + 6
        body.append(text(10, y + rh / 2 + 4, label, 12))
        pts = [(t0, value_at(ch[name], t0))]
        for t, v in ch[name]:
            if t0 < t < t1 and v != pts[-1][1]:  # VCDs may repeat unchanged values
                pts.append((t, v))
        pts.append((t1, None))
        one_bit = all(len(v) == 1 for _, v in ch[name])
        for (ta, va), (tb, _) in zip(pts, pts[1:]):
            xa, xb = sx(ta), sx(tb)
            if one_bit:
                yv = hi if va == "1" else lo
                body.append(f"<line x1='{xa}' y1='{yv}' x2='{xb}' y2='{yv}' stroke='#0d6efd' stroke-width='1.6'/>")
                if tb != t1:
                    body.append(f"<line x1='{xb}' y1='{hi}' x2='{xb}' y2='{lo}' stroke='#0d6efd' stroke-width='1.6'/>")
            else:
                m, e = (hi + lo) / 2, min(4, (xb - xa) / 2)
                body.append(f"<polygon points='{xa},{m} {xa + e},{hi} {xb - e},{hi} {xb},{m} {xb - e},{lo} {xa + e},{lo}' "
                            f"fill='#f1f6ff' stroke='#0d6efd' stroke-width='1'/>")
                if xb - xa > 14:
                    body.append(text((xa + xb) / 2, m + 4, fmt(va), 10, "middle"))
    with open(out, "w") as f:
        f.write(svg(width, height, body))


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("diagram", "wave"):
        sys.exit(__doc__)
    a = sys.argv[2:]
    if sys.argv[1] == "diagram":
        rng = (int(a[4]), int(a[5])) if len(a) > 5 else (None, None)
        diagram(a[0], a[1], a[2], a[3], *rng)
    else:
        wave(a[0], a[1], a[2], int(a[3]), int(a[4]), a[5:])
