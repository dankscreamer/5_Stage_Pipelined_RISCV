# ==============================================================================
# Simple Makefile for RISC-V Single-Cycle Processor Simulation
# ==============================================================================

IVERILOG = iverilog
VVP      = vvp
TB_SRC   = modules/tb_riscv.v
SIM_OUT  = sim.out
VCD_FILE = riscv_single_cycle.vcd

.PHONY: all sim test-branch test-arithmetic test-memory clean help

# Default target: compile and run current simulation
all: sim

sim:
	@echo "--- Compiling and Running Simulation ---"
	$(IVERILOG) -o $(SIM_OUT) $(TB_SRC)
	$(VVP) $(SIM_OUT)
	@echo "Simulation complete! Waveform saved to $(VCD_FILE)"

# Run Test 1: Conditional Branch (BEQ)
test-branch:
	@echo "--- Running Test 1: Branch (BEQ Taken) ---"
	cp program_branch.hex program.hex
	$(IVERILOG) -o $(SIM_OUT) $(TB_SRC)
	$(VVP) $(SIM_OUT)

# Run Test 2: Arithmetic and Logic Instructions (ADD, SUB, AND, OR, XOR)
test-arithmetic:
	@echo "--- Running Test 2: Arithmetic & Logic ---"
	cp program_arithmetic.hex program.hex
	$(IVERILOG) -o $(SIM_OUT) $(TB_SRC)
	$(VVP) $(SIM_OUT)

# Run Test 3: Data Memory Operations (SW and LW)
test-memory:
	@echo "--- Running Test 3: Memory Store & Load ---"
	cp program_memory.hex program.hex
	$(IVERILOG) -o $(SIM_OUT) $(TB_SRC)
	$(VVP) $(SIM_OUT)

# Remove temporary simulation files
clean:
	@echo "--- Cleaning up simulation files ---"
	rm -f $(SIM_OUT) $(VCD_FILE)
