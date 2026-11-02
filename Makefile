# ==============================================================================
# Makefile for KOCTA-16 SoC Coursework (VS ASOIU 2026, Variant 16)
# Student: Khodina A. P. (IU5-51B), BMSTU
#
# Tasks:
#   - Grade 3 (Task 16): Binary Search in RAM (16 elements)
#   - Grade 4 (Task 23): Washing Machine FSM Controller (MMIO LED & Timer)
#   - Grade 5 (Task 18): Interactive Sokoban 10x10 Puzzle (PUSH_LOGIC Accel)
# ==============================================================================

PYTHON ?= python3
IVERILOG ?= iverilog
RTL_SRCS = rtl/push_logic.v rtl/cross_xor.v rtl/alu.v rtl/register_file.v rtl/cpu_core.v rtl/memory_top.v rtl/mmio.v rtl/soc_top.v
FLAGS ?= -Wall -g2012 -I rtl


.PHONY: all assemble sim_all sim_grade3 sim_grade4 sim_grade5 play_sokoban report clean

all: assemble sim_all

# 1. Assemble all firmware programs
assemble:
	@echo "=== Assembling Firmware Programs for Variant 16 ==="
	$(PYTHON) toolchain/assembler.py asm/grade3_binary_search.asm firmware/binary_search.hex firmware/binary_search.lst
	$(PYTHON) firmware/gen_ram.py
	$(PYTHON) toolchain/assembler.py asm/grade4_washing_machine.asm firmware/washing_machine.hex firmware/washing_machine.lst
	$(PYTHON) toolchain/assembler.py asm/grade5_sokoban.asm firmware/sokoban.hex firmware/sokoban.lst
	@echo ">>> All firmware successfully assembled."

# 2. Run all simulations
sim_all: assemble sim_grade3 sim_grade4 sim_grade5
	@echo "========================================================"
	@echo ">>> ALL VARIANT 16 SIMULATIONS PASSED 100%!"
	@echo "========================================================"

# Grade 3: Binary Search
sim_grade3: assemble
	@echo "\n=== Running Grade 3 Simulation: Task 16 (Binary Search) ==="
	$(IVERILOG) $(FLAGS) -o sim/tb_binary_search.vvp $(RTL_SRCS) sim/tb_binary_search.v
	$(VVP) sim/tb_binary_search.vvp

# Grade 4: Washing Machine
sim_grade4: assemble
	@echo "\n=== Running Grade 4 Simulation: Task 23 (Washing Machine FSM) ==="
	$(IVERILOG) $(FLAGS) -o sim/tb_washing_machine.vvp $(RTL_SRCS) sim/tb_washing_machine.v
	$(VVP) sim/tb_washing_machine.vvp

# Grade 5: Sokoban Game with PUSH_LOGIC
sim_grade5: assemble
	@echo "\n=== Running Grade 5 Simulation: Task 18 (Sokoban + PUSH_LOGIC) ==="
	$(IVERILOG) $(FLAGS) -o sim/tb_sokoban.vvp $(RTL_SRCS) sim/tb_sokoban.v
	$(VVP) sim/tb_sokoban.vvp

# Launch Interactive Sokoban Game in Terminal
play_sokoban: assemble
	@echo "=== Launching Interactive Sokoban (10x10 Maze) ==="
	$(PYTHON) sim/play_sokoban.py

# Generate Official Coursework Word Report (.docx)
report:
	$(PYTHON) docs/make_docx_report.py

# Clean build artifacts
clean:
	rm -f sim/*.vvp sim/*.vcd
