#!/usr/bin/env python3
# coding: utf-8

# distributed under the mit license
# https://opensource.org/licenses/mit-license.php

"""
CocoTB Entry point
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

class TB:
    def __init__(self, dut):
        self.dut = dut

    async def start_clock(self):
        cocotb.start_soon(Clock(self.dut.aclk, 10, unit="ns").start())
        cocotb.start_soon(Clock(self.dut.slv0_aclk, 10, unit="ns").start())
        cocotb.start_soon(Clock(self.dut.slv1_aclk, 10, unit="ns").start())
        cocotb.start_soon(Clock(self.dut.slv2_aclk, 10, unit="ns").start())
        cocotb.start_soon(Clock(self.dut.slv3_aclk, 10, unit="ns").start())
        cocotb.start_soon(Clock(self.dut.mst0_aclk, 10, unit="ns").start())
        cocotb.start_soon(Clock(self.dut.mst1_aclk, 10, unit="ns").start())
        cocotb.start_soon(Clock(self.dut.mst2_aclk, 10, unit="ns").start())
        cocotb.start_soon(Clock(self.dut.mst3_aclk, 10, unit="ns").start())

    async def reset(self, cycles=100):

        # Used resets
        self.dut.srst.value = 0
        self.dut.slv0_srst.value = 0
        self.dut.slv1_srst.value = 0
        self.dut.slv2_srst.value = 0
        self.dut.slv3_srst.value = 0
        self.dut.mst0_srst.value = 0
        self.dut.mst1_srst.value = 0
        self.dut.mst2_srst.value = 0
        self.dut.mst3_srst.value = 0

        # Assert async resets
        self.dut.aresetn.value = 0
        self.dut.slv0_aresetn.value = 0
        self.dut.slv1_aresetn.value = 0
        self.dut.slv2_aresetn.value = 0
        self.dut.slv3_aresetn.value = 0
        self.dut.mst0_aresetn.value = 0
        self.dut.mst1_aresetn.value = 0
        self.dut.mst2_aresetn.value = 0
        self.dut.mst3_aresetn.value = 0

        for _ in range(cycles):
            await RisingEdge(self.dut.aclk)

        # Release them
        self.dut.aresetn.value = 1
        self.dut.slv0_aresetn.value = 1
        self.dut.slv1_aresetn.value = 1
        self.dut.slv2_aresetn.value = 1
        self.dut.slv3_aresetn.value = 1
        self.dut.mst0_aresetn.value = 1
        self.dut.mst1_aresetn.value = 1
        self.dut.mst2_aresetn.value = 1
        self.dut.mst3_aresetn.value = 1

        # Wait for few cycles to finish the reset phase
        for _ in range(5):
            await RisingEdge(self.dut.aclk)

    async def reset_ios(self):

        self.dut.slv0_awvalid.value = 0
        self.dut.slv0_awaddr.value = 0
        self.dut.slv0_awlen.value = 0
        self.dut.slv0_awsize.value = 0
        self.dut.slv0_awburst.value = 0
        self.dut.slv0_awlock.value = 0
        self.dut.slv0_awcache.value = 0
        self.dut.slv0_awprot.value = 0
        self.dut.slv0_awqos.value = 0
        self.dut.slv0_awregion.value = 0
        self.dut.slv0_awid.value = 0
        self.dut.slv0_awuser.value = 0
        self.dut.slv0_wvalid.value = 0
        self.dut.slv0_wlast.value = 0
        self.dut.slv0_wdata.value = 0
        self.dut.slv0_wstrb.value = 0
        self.dut.slv0_wuser.value = 0
        self.dut.slv0_bready.value = 0
        self.dut.slv0_arvalid.value = 0
        self.dut.slv0_araddr.value = 0
        self.dut.slv0_arlen.value = 0
        self.dut.slv0_arsize.value = 0
        self.dut.slv0_arburst.value = 0
        self.dut.slv0_arlock.value = 0
        self.dut.slv0_arcache.value = 0
        self.dut.slv0_arprot.value = 0
        self.dut.slv0_arqos.value = 0
        self.dut.slv0_arregion.value = 0
        self.dut.slv0_arid.value = 0
        self.dut.slv0_aruser.value = 0
        self.dut.slv0_rready.value = 0

        self.dut.slv1_awvalid.value = 0
        self.dut.slv1_awaddr.value = 0
        self.dut.slv1_awlen.value = 0
        self.dut.slv1_awsize.value = 0
        self.dut.slv1_awburst.value = 0
        self.dut.slv1_awlock.value = 0
        self.dut.slv1_awcache.value = 0
        self.dut.slv1_awprot.value = 0
        self.dut.slv1_awqos.value = 0
        self.dut.slv1_awregion.value = 0
        self.dut.slv1_awid.value = 0
        self.dut.slv1_awuser.value = 0
        self.dut.slv1_wvalid.value = 0
        self.dut.slv1_wlast.value = 0
        self.dut.slv1_wdata.value = 0
        self.dut.slv1_wstrb.value = 0
        self.dut.slv1_wuser.value = 0
        self.dut.slv1_bready.value = 0
        self.dut.slv1_arvalid.value = 0
        self.dut.slv1_araddr.value = 0
        self.dut.slv1_arlen.value = 0
        self.dut.slv1_arsize.value = 0
        self.dut.slv1_arburst.value = 0
        self.dut.slv1_arlock.value = 0
        self.dut.slv1_arcache.value = 0
        self.dut.slv1_arprot.value = 0
        self.dut.slv1_arqos.value = 0
        self.dut.slv1_arregion.value = 0
        self.dut.slv1_arid.value = 0
        self.dut.slv1_aruser.value = 0
        self.dut.slv1_rready.value = 0

        self.dut.slv2_awvalid.value = 0
        self.dut.slv2_awaddr.value = 0
        self.dut.slv2_awlen.value = 0
        self.dut.slv2_awsize.value = 0
        self.dut.slv2_awburst.value = 0
        self.dut.slv2_awlock.value = 0
        self.dut.slv2_awcache.value = 0
        self.dut.slv2_awprot.value = 0
        self.dut.slv2_awqos.value = 0
        self.dut.slv2_awregion.value = 0
        self.dut.slv2_awid.value = 0
        self.dut.slv2_awuser.value = 0
        self.dut.slv2_wvalid.value = 0
        self.dut.slv2_wlast.value = 0
        self.dut.slv2_wdata.value = 0
        self.dut.slv2_wstrb.value = 0
        self.dut.slv2_wuser.value = 0
        self.dut.slv2_bready.value = 0
        self.dut.slv2_arvalid.value = 0
        self.dut.slv2_araddr.value = 0
        self.dut.slv2_arlen.value = 0
        self.dut.slv2_arsize.value = 0
        self.dut.slv2_arburst.value = 0
        self.dut.slv2_arlock.value = 0
        self.dut.slv2_arcache.value = 0
        self.dut.slv2_arprot.value = 0
        self.dut.slv2_arqos.value = 0
        self.dut.slv2_arregion.value = 0
        self.dut.slv2_arid.value = 0
        self.dut.slv2_aruser.value = 0
        self.dut.slv2_rready.value = 0

        self.dut.slv3_awvalid.value = 0
        self.dut.slv3_awaddr.value = 0
        self.dut.slv3_awlen.value = 0
        self.dut.slv3_awsize.value = 0
        self.dut.slv3_awburst.value = 0
        self.dut.slv3_awlock.value = 0
        self.dut.slv3_awcache.value = 0
        self.dut.slv3_awprot.value = 0
        self.dut.slv3_awqos.value = 0
        self.dut.slv3_awregion.value = 0
        self.dut.slv3_awid.value = 0
        self.dut.slv3_awuser.value = 0
        self.dut.slv3_wvalid.value = 0
        self.dut.slv3_wlast.value = 0
        self.dut.slv3_wdata.value = 0
        self.dut.slv3_wstrb.value = 0
        self.dut.slv3_wuser.value = 0
        self.dut.slv3_bready.value = 0
        self.dut.slv3_arvalid.value = 0
        self.dut.slv3_araddr.value = 0
        self.dut.slv3_arlen.value = 0
        self.dut.slv3_arsize.value = 0
        self.dut.slv3_arburst.value = 0
        self.dut.slv3_arlock.value = 0
        self.dut.slv3_arcache.value = 0
        self.dut.slv3_arprot.value = 0
        self.dut.slv3_arqos.value = 0
        self.dut.slv3_arregion.value = 0
        self.dut.slv3_arid.value = 0
        self.dut.slv3_aruser.value = 0
        self.dut.slv3_rready.value = 0

        self.dut.mst0_awready.value = 0
        self.dut.mst0_wready.value = 0
        self.dut.mst0_bvalid.value = 0
        self.dut.mst0_bid.value = 0
        self.dut.mst0_bresp.value = 0
        self.dut.mst0_buser.value = 0
        self.dut.mst0_arready.value = 0
        self.dut.mst0_rvalid.value = 0
        self.dut.mst0_rdata.value = 0
        self.dut.mst0_rlast.value = 0
        self.dut.mst0_rid.value = 0
        self.dut.mst0_rresp.value = 0
        self.dut.mst0_ruser.value = 0
        self.dut.mst1_awready.value = 0
        self.dut.mst1_wready.value = 0
        self.dut.mst1_bvalid.value = 0
        self.dut.mst1_bid.value = 0
        self.dut.mst1_bresp.value = 0
        self.dut.mst1_buser.value = 0
        self.dut.mst1_arready.value = 0
        self.dut.mst1_rvalid.value = 0
        self.dut.mst1_rdata.value = 0
        self.dut.mst1_rlast.value = 0
        self.dut.mst1_rid.value = 0
        self.dut.mst1_rresp.value = 0
        self.dut.mst1_ruser.value = 0
        self.dut.mst2_awready.value = 0
        self.dut.mst2_wready.value = 0
        self.dut.mst2_bvalid.value = 0
        self.dut.mst2_bid.value = 0
        self.dut.mst2_bresp.value = 0
        self.dut.mst2_buser.value = 0
        self.dut.mst2_arready.value = 0
        self.dut.mst2_rvalid.value = 0
        self.dut.mst2_rdata.value = 0
        self.dut.mst2_rlast.value = 0
        self.dut.mst2_rid.value = 0
        self.dut.mst2_rresp.value = 0
        self.dut.mst2_ruser.value = 0
        self.dut.mst3_awready.value = 0
        self.dut.mst3_wready.value = 0
        self.dut.mst3_bvalid.value = 0
        self.dut.mst3_bid.value = 0
        self.dut.mst3_bresp.value = 0
        self.dut.mst3_buser.value = 0
        self.dut.mst3_arready.value = 0
        self.dut.mst3_rvalid.value = 0
        self.dut.mst3_rdata.value = 0
        self.dut.mst3_rlast.value = 0
        self.dut.mst3_rid.value = 0
        self.dut.mst3_rresp.value = 0
        self.dut.mst3_ruser.value = 0

    async def setup(self):
        await self.start_clock()
        await self.reset_ios()
        await self.reset()

    async def wait_cycles(self, n):
        for _ in range(n):
            await RisingEdge(self.dut.aclk)


async def create_tb(dut):
    tb = TB(dut)
    await tb.setup()
    return tb
