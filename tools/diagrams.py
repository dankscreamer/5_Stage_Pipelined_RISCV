#!/usr/bin/env python3
"""Draw the architecture figures as standalone SVG (no third-party packages).

Usage:  python3 tools/diagrams.py OUT_DIR

Writes OUT_DIR/block_diagram.svg   the 5-stage pipelined CPU (pipeline_top.v)
       OUT_DIR/predictor_fsm.svg   the 2-bit counter state machine (branch_predictor.v)
"""
import os
import sys
from xml.sax.saxutils import escape

FONT = "font-family='Helvetica, Arial, sans-serif'"
INK, QUIET, EDGE = "#212529", "#6c757d", "#495057"
DATA, CTRL, FWD, REDIR = "#343a40", "#6c757d", "#b02a37", "#0d6efd"
STAGE_FILL = {"IF": "#e7f0ff", "ID": "#e6f4ec", "EX": "#fff6dc", "MEM": "#fdebed", "WB": "#f1ecfa"}


class Svg:
    """Tiny SVG builder: boxes, muxes, wires with arrowheads, labels."""

    def __init__(self, w, h):
        self.w, self.h, self.body = w, h, []

    def text(self, x, y, s, size=12, anchor="middle", color=INK, weight="normal", italic=False):
        style = " font-style='italic'" if italic else ""
        self.body.append(f"<text x='{x}' y='{y}' font-size='{size}' text-anchor='{anchor}' fill='{color}' "
                         f"font-weight='{weight}'{style} {FONT}>{escape(s)}</text>")

    def box(self, x, y, w, h, lines, fill="white", stroke=EDGE, size=12, bold_first=True, dash=False):
        d = " stroke-dasharray='5 3'" if dash else ""
        self.body.append(f"<rect x='{x}' y='{y}' width='{w}' height='{h}' rx='6' fill='{fill}' "
                         f"stroke='{stroke}' stroke-width='1.3'{d}/>")
        lh = size + 3
        y0 = y + h / 2 - (len(lines) - 1) * lh / 2 + size / 3
        for i, s in enumerate(lines):
            self.text(x + w / 2, y0 + i * lh, s, size if i == 0 else size - 1.5,
                      weight="bold" if (i == 0 and bold_first) else "normal",
                      color=INK if i == 0 else QUIET)

    def mux(self, x, y, w, h, label=""):
        self.body.append(f"<polygon points='{x},{y} {x + w},{y + 8} {x + w},{y + h - 8} {x},{y + h}' "
                         f"fill='white' stroke='{EDGE}' stroke-width='1.3'/>")
        if label:
            self.text(x + w / 2, y - 6, label, 10.5, color=QUIET)

    def wire(self, pts, color=DATA, dash=False, arrow=True, width=1.4):
        d = "M" + " L".join(f"{x},{y}" for x, y in pts)
        da = " stroke-dasharray='5 3'" if dash else ""
        mk = f" marker-end='url(#arrow-{color[1:]})'" if arrow else ""
        self.body.append(f"<path d='{d}' fill='none' stroke='{color}' stroke-width='{width}'{da}{mk}/>")

    def dot(self, x, y, color=DATA):
        self.body.append(f"<circle cx='{x}' cy='{y}' r='3' fill='{color}'/>")

    def save(self, path, title):
        colors = {DATA, CTRL, FWD, REDIR, EDGE}
        defs = "".join(f"<marker id='arrow-{c[1:]}' viewBox='0 0 10 10' refX='9' refY='5' markerWidth='7' "
                       f"markerHeight='7' orient='auto-start-reverse'><path d='M0 0L10 5L0 10z' fill='{c}'/></marker>"
                       for c in colors)
        with open(path, "w") as f:
            f.write(f"<svg xmlns='http://www.w3.org/2000/svg' width='{self.w}' height='{self.h}' "
                    f"viewBox='0 0 {self.w} {self.h}' role='img' aria-label='{escape(title)}'>\n"
                    f"<defs>{defs}</defs>\n<rect width='100%' height='100%' fill='white'/>\n"
                    + "\n".join(self.body) + "\n</svg>\n")


def block_diagram(path):
    s = Svg(1480, 830)
    s.text(30, 30, "5-stage pipelined RISC-V CPU (pipeline_top.v)", 18, "start", weight="bold")
    s.text(30, 50, "IF → ID → EX → MEM → WB with forwarding, hazard detection and branch prediction",
           12.5, "start", QUIET)

    # stage bands and pipeline registers
    cols = {"IF": (30, 300), "ID": (342, 640), "EX": (682, 1030), "MEM": (1072, 1230), "WB": (1272, 1450)}
    names = {"IF": "IF · fetch", "ID": "ID · decode", "EX": "EX · execute", "MEM": "MEM · memory", "WB": "WB · write-back"}
    for k, (x0, x1) in cols.items():
        s.body.append(f"<rect x='{x0}' y='88' width='{x1 - x0}' height='600' rx='10' fill='{STAGE_FILL[k]}'/>")
        s.text((x0 + x1) / 2, 108, names[k], 13.5, weight="bold")
    regs = [("IF/ID", 312), ("ID/EX", 652), ("EX/MEM", 1042), ("MEM/WB", 1242)]
    for name, x in regs:
        s.body.append(f"<rect x='{x}' y='120' width='18' height='440' rx='3' fill='#ced4da' stroke='{EDGE}'/>")
        s.text(x + 9, 82, name, 10.5, color=QUIET, weight="bold")

    # ---------------- IF ----------------
    s.mux(70, 250, 24, 160, "PC mux")
    s.box(118, 305, 62, 50, ["PC"])
    s.box(205, 285, 92, 90, ["Instruction", "memory", "(block RAM)"], size=11.5)
    s.box(118, 168, 62, 44, ["+4"])
    s.box(205, 440, 84, 92, ["BTB", "8 entries,", "2-bit ctr", "BP = 2"], fill="#eef4ff", size=11.5)
    s.wire([(94, 330), (118, 330)])
    s.wire([(180, 330), (205, 330)])
    s.wire([(297, 330), (312, 330)])
    s.dot(190, 330)
    s.wire([(190, 330), (190, 486), (205, 486)])                       # PC -> BTB lookup
    s.dot(149, 305)
    s.wire([(149, 305), (149, 212)])                                   # PC -> +4
    s.wire([(118, 190), (54, 190), (54, 270), (70, 270)])              # PC+4 -> mux
    s.text(60, 184, "PC+4", 10, "start", QUIET)
    s.wire([(247, 532), (247, 548), (62, 548), (62, 305), (70, 305)], color=REDIR)   # BTB target
    s.text(160, 543, "BTB target", 10, "start", REDIR)
    s.wire([(289, 466), (312, 466)], color=REDIR)
    s.text(300, 459, "pred", 9.5, color=REDIR)

    # ---------------- ID ----------------
    s.box(355, 135, 110, 52, ["Control unit", "opcode → signals"], size=11.5)
    s.box(470, 268, 130, 116, ["Register file", "32 × 32, 2 read /", "1 write port,", "write-through", "bypass"],
          size=11.5)
    s.box(355, 420, 100, 46, ["Imm gen", "I / S / B / J"], size=11.5)
    s.box(470, 478, 140, 56, ["Static predictor", "pc + imm, backward", "→ taken (BP = 1)"],
          fill="#eef4ff", size=11.5)
    s.box(355, 612, 110, 52, ["Hazard unit", "stall / flush"], fill="#f8f9fa", size=11.5)
    s.wire([(330, 158), (355, 158)])
    s.wire([(465, 158), (652, 158)], color=CTRL)
    s.text(515, 155, "control signals", 10, color=QUIET)
    s.wire([(330, 300), (470, 300)])
    s.text(400, 294, "rs1, rs2", 10, color=QUIET)
    s.wire([(600, 326), (652, 326)])
    s.text(626, 320, "values", 9.5, color=QUIET)
    s.wire([(330, 443), (355, 443)])
    s.wire([(455, 443), (652, 443)])
    s.text(560, 437, "imm", 10, color=QUIET)
    s.wire([(540, 534), (540, 576), (44, 576), (44, 340), (70, 340)], color=REDIR)   # static target
    s.text(380, 590, "static target", 10, "start", REDIR)
    # write-back into the register file (from WB, over the top)
    s.wire([(1436, 305), (1436, 66), (580, 66), (580, 268)], color=DATA)
    s.text(1000, 60, "write-back to the register file: rd, result (reg_write)", 10.5, color=DATA)
    # stall / flush control from the hazard unit
    s.wire([(355, 638), (321, 638), (321, 560)], color=CTRL, dash=True)
    s.wire([(321, 638), (149, 638), (149, 355)], color=CTRL, dash=True)
    s.wire([(465, 638), (661, 638), (661, 560)], color=CTRL, dash=True)
    s.text(232, 632, "PC enable", 10, color=CTRL)
    s.text(565, 632, "stall / flush", 10, color=CTRL)

    # ---------------- EX ----------------
    s.mux(700, 248, 22, 74, "fwd A")
    s.mux(700, 348, 22, 74, "fwd B")
    s.mux(745, 368, 20, 66)
    s.body.append("<polygon points='790,250 860,280 860,400 790,430 790,355 805,340 790,325' "
                  f"fill='white' stroke='{EDGE}' stroke-width='1.3'/>")
    s.text(835, 345, "ALU", 13, weight="bold")
    s.box(790, 135, 92, 46, ["ALU control"], size=11.5)
    s.box(790, 455, 92, 40, ["== compare"], size=11.5)
    s.box(790, 512, 92, 40, ["pc + imm"], size=11.5)
    s.box(905, 455, 115, 97, ["Branch check", "taken ≠ predicted", "→ redirect PC,", "flush 2 stages"],
          fill="#eef4ff", size=11.5)
    s.box(700, 612, 165, 52, ["Forwarding unit", "rs vs rd in EX/MEM, MEM/WB"], fill="#f8f9fa", size=11.5)
    s.wire([(670, 262), (700, 262)])
    s.wire([(670, 362), (700, 362)])
    s.wire([(722, 285), (790, 285)])
    s.wire([(722, 385), (745, 385)])
    s.wire([(670, 443), (735, 443), (735, 418), (745, 418)])           # imm -> ALU src mux
    s.wire([(765, 400), (790, 400)])
    s.wire([(670, 158), (790, 158)], color=CTRL)
    s.wire([(836, 181), (836, 268)], color=CTRL, dash=True)
    s.dot(772, 285)
    s.wire([(772, 285), (772, 467), (790, 467)])                       # operand A -> compare
    s.dot(740, 385)
    s.wire([(740, 385), (740, 485), (790, 485)])                       # operand B -> compare
    s.wire([(670, 532), (790, 532)])
    s.text(746, 526, "pc, imm", 10, "start", QUIET)
    s.wire([(882, 475), (905, 475)])
    s.wire([(882, 532), (905, 532)])
    s.wire([(860, 340), (1042, 340)])
    s.text(950, 334, "ALU result", 10.5, color=QUIET)
    s.wire([(783, 612), (783, 600), (711, 600), (711, 422)], color=CTRL, dash=True)
    s.text(716, 596, "select", 10, "start", CTRL)
    # forwarding data paths (red)
    s.dot(1066, 340, FWD)
    s.wire([(1066, 340), (1066, 572), (684, 572), (684, 385), (700, 385)], color=FWD)
    s.wire([(684, 285), (700, 285)], color=FWD)
    s.dot(684, 385, FWD)
    s.dot(1350, 305, FWD)
    s.wire([(1350, 305), (1350, 580), (692, 580), (692, 408), (700, 408)], color=FWD)
    s.wire([(692, 308), (700, 308)], color=FWD)
    s.dot(692, 408, FWD)
    s.text(880, 566, "forward from EX/MEM", 10, color=FWD)
    s.text(1150, 594, "forward from MEM/WB", 10, color=FWD)
    # redirect from EX to the PC mux and the hazard unit
    s.wire([(962, 552), (962, 708), (34, 708), (34, 380), (70, 380)], color=REDIR)
    s.text(500, 702, "mispredict: correct PC", 10.5, color=REDIR)
    s.dot(410, 708, REDIR)
    s.wire([(410, 708), (410, 664)], color=REDIR, dash=True)
    # BTB update from EX
    s.wire([(1000, 552), (1000, 724), (275, 724), (275, 532)], color=REDIR, dash=True)
    s.text(640, 740, "BTB update: branch PC, taken, target", 10.5, color=REDIR)

    # ---------------- MEM ----------------
    s.box(1085, 285, 135, 110, ["Data memory", "(block RAM)", "sync write,", "registered read"], size=11.5)
    s.wire([(1066, 340), (1085, 340)])
    s.wire([(1060, 372), (1085, 372)])
    s.text(1152, 412, "store data = forwarded rs2", 9.5, color=QUIET)
    s.wire([(1220, 340), (1242, 340)])
    s.dot(1066, 268)
    s.wire([(1060, 268), (1242, 268)])
    s.text(1150, 262, "ALU result", 10, color=QUIET)

    # ---------------- WB ----------------
    s.mux(1290, 250, 24, 110, "result")
    s.wire([(1260, 268), (1290, 268)])
    s.wire([(1260, 340), (1290, 340)])
    s.wire([(1314, 305), (1436, 305)], arrow=False)
    s.text(1400, 420, "rd and reg_write", 10.5, color=QUIET)
    s.text(1400, 435, "travel with the", 10.5, color=QUIET)
    s.text(1400, 450, "instruction", 10.5, color=QUIET)

    # legend
    y = 772
    for i, (c, dash, label) in enumerate([(DATA, False, "data path"), (CTRL, True, "control (stall, flush, select)"),
                                          (FWD, False, "forwarding"), (REDIR, False, "branch prediction / redirect")]):
        x = 30 + i * 300
        s.wire([(x, y), (x + 40, y)], color=c, dash=dash)
        s.text(x + 50, y + 4, label, 11.5, "start", INK)
    s.text(30, 806, "BP = BRANCH_PRED parameter: 0 none, 1 static (ID), 2 dynamic BTB (IF). "
           "PC mux priority: EX redirect > static target > BTB target > PC+4.", 11, "start", QUIET)
    s.save(path, "5-stage pipelined RISC-V CPU block diagram")


def predictor_fsm(path):
    s = Svg(980, 430)
    s.text(30, 32, "Branch predictor: 2-bit saturating counter per BTB entry (branch_predictor.v)",
           16, "start", weight="bold")
    s.text(30, 52, "Updated in EX when a branch resolves. Prediction = counter's upper bit.", 12, "start", QUIET)
    xs, cy, r = [220, 400, 580, 760], 210, 52
    states = [("00", "strongly", "not taken"), ("01", "weakly", "not taken"),
              ("10", "weakly", "taken"), ("11", "strongly", "taken")]
    for x, (code, a, b) in zip(xs, states):
        taken = code[0] == "1"
        s.body.append(f"<circle cx='{x}' cy='{cy}' r='{r}' fill='{'#e7f0ff' if taken else '#f8f9fa'}' "
                      f"stroke='{REDIR if taken else EDGE}' stroke-width='{2 if taken else 1.3}'/>")
        s.text(x, cy - 10, code, 17, weight="bold")
        s.text(x, cy + 10, a, 11.5, color=QUIET)
        s.text(x, cy + 25, b, 11.5, color=QUIET)
    # taken: arcs over the top, left -> right
    for a, b in zip(xs, xs[1:]):
        s.body.append(f"<path d='M{a + 30},{cy - 43} Q{(a + b) / 2},{cy - 105} {b - 30},{cy - 43}' fill='none' "
                      f"stroke='{REDIR}' stroke-width='1.5' marker-end='url(#arrow-{REDIR[1:]})'/>")
        s.text((a + b) / 2, cy - 82, "taken", 11.5, color=REDIR)
    # not taken: arcs under the bottom, right -> left
    for a, b in zip(xs, xs[1:]):
        s.body.append(f"<path d='M{b - 30},{cy + 43} Q{(a + b) / 2},{cy + 105} {a + 30},{cy + 43}' fill='none' "
                      f"stroke='{EDGE}' stroke-width='1.5' marker-end='url(#arrow-{EDGE[1:]})'/>")
        s.text((a + b) / 2, cy + 92, "not taken", 11.5, color=EDGE)
    # saturating self-loops
    s.body.append(f"<path d='M{xs[0] - 40},{cy + 33} C{xs[0] - 120},{cy + 80} {xs[0] - 120},{cy - 80} "
                  f"{xs[0] - 40},{cy - 33}' fill='none' stroke='{EDGE}' stroke-width='1.5' "
                  f"marker-end='url(#arrow-{EDGE[1:]})'/>")
    s.text(xs[0] - 104, cy + 4, "not taken", 11, "end", EDGE)
    s.body.append(f"<path d='M{xs[3] + 40},{cy - 33} C{xs[3] + 120},{cy - 80} {xs[3] + 120},{cy + 80} "
                  f"{xs[3] + 40},{cy + 33}' fill='none' stroke='{REDIR}' stroke-width='1.5' "
                  f"marker-end='url(#arrow-{REDIR[1:]})'/>")
    s.text(xs[3] + 104, cy + 4, "taken", 11, "start", REDIR)
    # allocation on a taken BTB miss
    s.box(465, 330, 250, 44, ["BTB miss + taken → allocate entry in 10", "BTB miss + not taken → no entry"],
          fill="white", size=11, bold_first=False)
    s.wire([(xs[2] - 10, 330), (xs[2] - 10, cy + r + 2)], color=REDIR, dash=True)
    s.body.append(f"<rect x='30' y='370' width='14' height='14' rx='3' fill='#e7f0ff' stroke='{REDIR}' stroke-width='2'/>")
    s.text(52, 382, "predict taken: next PC = BTB target", 11.5, "start")
    s.body.append(f"<rect x='30' y='394' width='14' height='14' rx='3' fill='#f8f9fa' stroke='{EDGE}'/>")
    s.text(52, 406, "predict not taken: next PC = PC + 4", 11.5, "start")
    s.save(path, "2-bit saturating counter state diagram")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    os.makedirs(sys.argv[1], exist_ok=True)
    block_diagram(os.path.join(sys.argv[1], "block_diagram.svg"))
    predictor_fsm(os.path.join(sys.argv[1], "predictor_fsm.svg"))
