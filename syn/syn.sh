#!/usr/bin/env bash

# -e: exit if one command fails
# -o pipefail: causes a pipeline to fail if any command fails
set -e -o pipefail

SRCS="\
../deps/dcfifo/src/vlog/async_fifo.v \
../deps/dcfifo/src/vlog/fifo_2mem.v \
../deps/dcfifo/src/vlog/fifomem_dp.v \
../deps/dcfifo/src/vlog/rptr_empty.v \
../deps/dcfifo/src/vlog/sync_ptr.v \
../deps/dcfifo/src/vlog/sync_r2w.v \
../deps/dcfifo/src/vlog/sync_w2r.v \
../deps/dcfifo/src/vlog/wptr_full.v \
../rtl/axicb_crossbar_top.sv \
../rtl/axicb_mst_if.sv \
../rtl/axicb_mst_switch.sv \
../rtl/axicb_pipeline.sv \
../rtl/axicb_round_robin.sv \
../rtl/axicb_round_robin_core.sv \
../rtl/axicb_scfifo.sv \
../rtl/axicb_scfifo_ram.sv \
../rtl/axicb_slv_if.sv \
../rtl/axicb_slv_switch.sv \
../rtl/axicb_switch_top.sv"

yosys -DARTY \
      -p "scratchpad -set xilinx_dsp.multonly 1" \
      -p "verilog_defaults -add -I../rtl" \
      -p "synth_xilinx -nowidelut -flatten -abc9 -arch xc7 -top axicb_crossbar_top " \
      $SRCS | tee syn.log

exit
