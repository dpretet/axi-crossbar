# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_INCLUDE_DIRS=$(PWD)/../../rtl/

VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_mst_if.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_mst_switch_rd.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_mst_switch_wr.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_mst_switch.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_pipeline.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_round_robin_core.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_round_robin.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_scfifo_ram.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_scfifo_regfile.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_scfifo.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_slv_if.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_slv_ooo.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_slv_switch_rd.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_slv_switch_wr.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_slv_switch.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_switch_top.sv
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_crossbar_top.sv

# COCOTB_TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
COCOTB_TOPLEVEL = axicb_crossbar_top

# COCOTB_TEST_MODULES is the basename of the Python test file(s)
COCOTB_TEST_MODULES = test_cdas

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
