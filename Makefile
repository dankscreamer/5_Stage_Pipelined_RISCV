# Simulation flow (Icarus Verilog). `make test` runs every unit test and every program.
IVERILOG ?= iverilog
VVP      ?= vvp
PYTHON   ?= python3
BUILD    := build
TOPS     := modules/single_cycle_top.v modules/pipeline_top.v
RTL      := $(filter-out $(TOPS),$(wildcard modules/*.v))
UNITS    := alu alu_control imm_gen reg_file control_unit data_mem pc forwarding_unit hazard_unit pipeline_regs
PROGRAMS := $(basename $(notdir $(wildcard programs/*.s)))

.PHONY: test unit single pipeline programs random perf synth figures trace clean

test: unit single pipeline

$(BUILD):
	mkdir -p $(BUILD)

# ---- unit tests ----
unit: | $(BUILD)
	@fail=0; for u in $(UNITS); do \
	  $(IVERILOG) -g2005 -Wall -Wno-timescale -o $(BUILD)/tb_$$u tb/tb_$$u.v $(RTL) || exit 1; \
	  out=$$($(VVP) -n $(BUILD)/tb_$$u); \
	  echo "$$out" | grep -E "RESULT|FAIL"; \
	  echo "$$out" | grep -q "RESULT: PASS" || fail=1; \
	done; exit $$fail

# ---- programs: assemble + reference model ----
programs: | $(BUILD)
	@for p in $(PROGRAMS); do $(PYTHON) tools/rvasm.py programs/$$p.s $(BUILD) || exit 1; done

# ---- single-cycle CPU, every program, self-checked against the reference model ----
single: programs
	@$(IVERILOG) -g2005 -Wall -Wno-timescale -o $(BUILD)/tb_single_cycle tb/tb_single_cycle.v $(RTL) modules/single_cycle_top.v
	@fail=0; for p in $(PROGRAMS); do \
	  out=$$($(VVP) -n $(BUILD)/tb_single_cycle +prog=$(BUILD)/$$p.hex +expected=$(BUILD)/$$p.expected +vcd=$(BUILD)/single_$$p.vcd); \
	  echo "$$out" | grep -E "RESULT|FAIL|cycles"; \
	  echo "$$out" | grep -q "RESULT: PASS" || fail=1; \
	done; exit $$fail

# ---- pipelined CPU, with and without forwarding, same programs and expected state ----
pipeline: programs
	@$(IVERILOG) -g2005 -Wall -Wno-timescale -o $(BUILD)/tb_pipeline_fwd1 tb/tb_pipeline.v $(RTL) modules/pipeline_top.v
	@$(IVERILOG) -g2005 -Wall -Wno-timescale -Ptb_pipeline.FORWARDING=0 -o $(BUILD)/tb_pipeline_fwd0 tb/tb_pipeline.v $(RTL) modules/pipeline_top.v
	@fail=0; for f in 1 0; do for p in $(PROGRAMS); do \
	  out=$$($(VVP) -n $(BUILD)/tb_pipeline_fwd$$f +prog=$(BUILD)/$$p.hex +expected=$(BUILD)/$$p.expected +vcd=$(BUILD)/pipe_fwd$${f}_$$p.vcd); \
	  echo "$$out" | grep -E "RESULT|FAIL|PERF"; \
	  echo "$$out" | grep -q "RESULT: PASS" || fail=1; \
	done; done; exit $$fail

# ---- benchmark table (results/perf.md); includes execution time once `make synth` has run ----
perf: pipeline single
	@$(PYTHON) tools/perf.py $(BUILD) results

# ---- FPGA synthesis + place & route (iCE40 HX8K): results/synth.md ----
synth: | $(BUILD)
	@$(PYTHON) tools/synth.py $(BUILD) results 3

# ---- report figures (SVG): pipeline diagrams + waveforms ----
P := tb_pipeline.dut
S := tb_single_cycle.dut
PIPE_SIGNALS := $(P).clk $(P).pc_current=IF.pc $(P).id_valid=ID.valid $(P).id_pc=ID.pc \
	$(P).ex_valid=EX.valid $(P).ex_pc=EX.pc $(P).mem_pc=MEM.pc $(P).wb_valid=WB.valid $(P).wb_pc=WB.pc \
	$(P).stall $(P).branch_taken $(P).forward_a $(P).forward_b $(P).wb_reg_write $(P).wb_rd $(P).wb_result
figures: pipeline single
	@mkdir -p figures
	@for f in 1 0; do $(VVP) -n $(BUILD)/tb_pipeline_fwd$$f +prog=$(BUILD)/demo_hazards.hex \
	  +expected=$(BUILD)/demo_hazards.expected +pipe=$(BUILD)/demo_fwd$$f.pipe +vcd=$(BUILD)/demo_fwd$$f.vcd | grep -q "RESULT: PASS" || exit 1; done
	@$(VVP) -n $(BUILD)/tb_pipeline_fwd1 +prog=$(BUILD)/bench_sum_rolled.hex \
	  +expected=$(BUILD)/bench_sum_rolled.expected +pipe=$(BUILD)/sum_rolled.pipe | grep -q "RESULT: PASS"
	@$(VVP) -n $(BUILD)/tb_single_cycle +prog=$(BUILD)/demo_hazards.hex \
	  +expected=$(BUILD)/demo_hazards.expected +vcd=$(BUILD)/demo_single.vcd | grep -q "RESULT: PASS"
	$(PYTHON) tools/figures.py diagram $(BUILD)/demo_fwd1.pipe $(BUILD)/demo_hazards.lst figures/pipeline_demo_fwd.svg \
	  "Pipeline diagram: demo_hazards, with forwarding (15 cycles)"
	$(PYTHON) tools/figures.py diagram $(BUILD)/demo_fwd0.pipe $(BUILD)/demo_hazards.lst figures/pipeline_demo_nofwd.svg \
	  "Pipeline diagram: demo_hazards, without forwarding (20 cycles)"
	$(PYTHON) tools/figures.py diagram $(BUILD)/sum_rolled.pipe $(BUILD)/bench_sum_rolled.lst figures/pipeline_sum_loop.svg \
	  "Pipeline diagram: bench_sum_rolled, two loop iterations (load-use stall + taken branch)" 402 417
	$(PYTHON) tools/figures.py wave $(BUILD)/demo_fwd1.vcd figures/wave_demo_fwd.svg \
	  "Waveform: pipelined CPU (forwarding), demo_hazards" 1 16 $(PIPE_SIGNALS)
	$(PYTHON) tools/figures.py wave $(BUILD)/demo_single.vcd figures/wave_demo_single.svg \
	  "Waveform: single-cycle CPU, demo_hazards" 1 9 $(S).clk $(S).pc_current=pc $(S).instruction \
	  $(S).alu_result $(S).reg_write $(S).result=wb_result $(S).mem_write $(S).branch_taken

# ---- random differential testing: all three CPUs vs the reference model ----
NRAND ?= 300
SEED  ?= 1
random: pipeline single
	@$(PYTHON) tools/randprog.py $(BUILD)/random $(NRAND) 60 $(SEED)
	@fail=0; n=0; for s in $(BUILD)/random/*.s; do \
	  p=$${s%.s}; $(PYTHON) tools/rvasm.py $$s $(BUILD)/random > /dev/null || exit 1; \
	  for sim in tb_single_cycle tb_pipeline_fwd1 tb_pipeline_fwd0; do \
	    out=$$($(VVP) -n $(BUILD)/$$sim +prog=$$p.hex +expected=$$p.expected); n=$$((n+1)); \
	    echo "$$out" | grep -q "RESULT: PASS" || { echo "$$out" | grep -E "FAIL"; echo "^ $$sim $$s"; fail=1; }; \
	  done; \
	done; echo "random: $$n runs, $$([ $$fail = 0 ] && echo all PASS || echo FAILURES)"; exit $$fail

# ---- cycle-by-cycle pipeline diagram: make trace PROG=fib [FWD=0] ----
PROG ?= alu_basic
FWD  ?= 1
trace: pipeline
	@$(VVP) -n $(BUILD)/tb_pipeline_fwd$(FWD) +prog=$(BUILD)/$(PROG).hex +expected=$(BUILD)/$(PROG).expected +trace | grep -v "^VCD"

clean:
	rm -rf $(BUILD)
