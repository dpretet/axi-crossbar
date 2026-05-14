# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

# Defaults
SIM ?= icarus
WAVES=1

# Load a configuration file to instantiate the core
CFG_FILE ?= ../tb_config/axi4_+cdc_+or_-priority_+pipe_-route.cfg
COMPILE_ARGS += $(shell python3 cfg_to_defines.py $(CFG_FILE))

TOPLEVEL_LANG ?= verilog

VERILOG_INCLUDE_DIRS=$(PWD)/../../rtl/
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/async_bidir_fifo.v
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/async_bidir_ramif_fifo.v
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/async_fifo.v
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/fifo_2mem.v
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/fifomem_dp.v
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/rptr_empty.v
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/sync_ptr.v
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/sync_r2w.v
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/sync_w2r.v
VERILOG_SOURCES+=$(PWD)/../../deps/dcfifo/src/vlog/wptr_full.v
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
VERILOG_SOURCES+=$(PWD)/../../rtl/axicb_crossbar_lite_top.sv
VERILOG_SOURCES+=$(PWD)/tb_axi4.sv

# COCOTB_TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
COCOTB_TOPLEVEL = tb_axi4

# COCOTB_TEST_MODULES is the basename of the Python test file(s)
COCOTB_TEST_MODULES = test_cdas

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
