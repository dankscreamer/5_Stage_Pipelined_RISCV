# Phase 1 baseline and Phase 2 pipeline simulation (run from the repo root).
IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
PROGRAM ?= program.hex
export IVERILOG VVP

.PHONY: all sim sim-pipeline test test-pipeline compare test-branch test-arithmetic test-memory clean help

all: sim

sim:
	mkdir -p .build
	$(IVERILOG) -g2012 -s tb_riscv -o .build/sim.out modules/tb_riscv.v
	$(VVP) .build/sim.out +PROGRAM=$(PROGRAM) +VCD=.build/riscv_single_cycle.vcd

sim-pipeline:
	$(PYTHON) tests/run_phase2.py --case branch --core pipeline

test compare:
	$(PYTHON) tests/run_phase2.py

test-pipeline:
	$(PYTHON) tests/run_phase2.py --core pipeline

test-branch:
	$(PYTHON) tests/run_phase2.py --case branch --core single

test-arithmetic:
	$(PYTHON) tests/run_phase2.py --case arithmetic --core single

test-memory:
	$(PYTHON) tests/run_phase2.py --case memory --core single

clean:
	rm -rf .build

help:
	@echo "make sim              Phase 1 waveform (PROGRAM=file.hex optional)"
	@echo "make sim-pipeline     Verify Phase 2 branch program and save waveform"
	@echo "make test / compare   Verify both cores and report measured cycles/time"
	@echo "make test-pipeline    Run only the Phase 2 checks"
	@echo "make test-branch / test-arithmetic / test-memory   Phase 1 checks"
	@echo "Outputs: .build/ (program.hex and archived waveforms are preserved)"
