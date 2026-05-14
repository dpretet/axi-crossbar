#!/usr/bin/env python3
# coding: utf-8

# distributed under the mit license
# https://opensource.org/licenses/mit-license.php

"""
Testcase to explore the CDAS feature
"""


import cocotb
from cocotb.triggers import FallingEdge, Timer


async def generate_clock(dut):
    """Generate clock pulses."""

    for _ in range(10):
        dut.aclk.value = 0
        await Timer(1, unit="ns")
        dut.aclk.value = 1
        await Timer(1, unit="ns")


@cocotb.test()
async def cdas_tc(dut):
    """Try accessing the design."""

    cocotb.start_soon(generate_clock(dut))  # run the clock "in the background"

    await Timer(5, unit="ns")  # wait a bit
    await FallingEdge(dut.aclk)  # wait for falling edge/"negedge"

    cocotb.log.info("slv0_awready is %s", dut.slv0_awready.value)
    assert dut.slv0_awready.value == 0
