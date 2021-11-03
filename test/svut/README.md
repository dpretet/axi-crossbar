# SystemVerilog Testbench

This testbench is a simple environment to stress the crossbar infrastructure
by randomly access slave nodes from up to four master nodes.

This testbench is focused on an AXI4-lite configuration of the crossbar with
following setup:

- 4 masters
- 4 slaves
- Use a full-mode STRB
- AXI_SIGNALING set to AXI4-lite mode
- No USER fields usage
- All masters have the same priority in arbitration stages
- All masters can access the two slaves

The master model is very simple and limited to a basic behavior. It doesn't
widely cover the corner cases of a complex crossbar. Further and better
coverage should be attained with a more advanced testbench architecture,
planned in the future with BFMs to validate the AXI4 protocol support.

Slaves are mapped over small memory spaces to ease and speed verification
Traffic injection is timely random, can be continuous or sparse.
Address and data are synchronous because of current crossbar limitations
Verification is done only on AXI4-lite for the first verification milestone


Scenario:

1/ Master initiates a read/write request
    - use a range of address for each slave (start/stop)
    - generate a random address + random sideband signals (PROT, ...)
    - generate a random data from address with LFSR
    - generate a random response

An address can be out of range, thus a DECERR response is recorded and checked.

2/ Slave receives a request and completes it

- receive an address and generate data from it with LFSR
- data are returned if read request
- generate a random response and return it

3/ Master receives the completion

- check response received against the generated one


The drivers can detect the following errors:

- Write outstanding request timeout
- Read outstanding request timeout
- AW request timeout
- W request timeout
- AR request timeout
- BRESP response error
- RRESP response error

The monitors can detect the following errors:

- B response timeout
- R response timeout
- WDATA error

The testbench includes several testcases using the above described scenarios,
limiting the address range target (and so the number of slaves), use on or more
master. The testbench is also setup by different configuration loaded by the
Bash front-end, relying on configuration files. The flow is launched as much
configuration are present in `tb_config` folder.
