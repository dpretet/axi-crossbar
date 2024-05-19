# SystemVerilog Testbench

## Overview

This testbench is a simple environment to stress the crossbar infrastructure
by randomly access slave nodes from up to four master nodes. It's built upon
Icarus Verilog 11 and relies on
[SVUT](https://github.com/dpretet/svut) to configure and execute the flow,
binded by a Bash front-end.

This testbench is focused on the configuration of the crossbar with
following setup:

- 4 masters
- 4 slaves
- All masters have the same priority in arbitration stages
- All masters can access the four slaves

The master model is very simple and limited to a basic behavior. It doesn't
widely cover the corner cases of a complex crossbar. Further and better
coverage should be attained with a more advanced testbench architecture,
planned in the future with BFMs to validate the AXI4 protocol support. However,
usage of LFSR and more generally its inner randomized behavior should ensure
a decent coverage of the core's features.

Slaves are mapped over small memory spaces to ease and speed verification.
Traffic injection is timely random, can be continuous or sparse, as the
completions. Slave monitor also uses LFSR to handshake with the core.

## Scenario

1/ Master initiates a read/write request
- use a range of address for each slave (start/stop)
- generate a random address + random sideband signals (PROT, ...)
- generate a random data from address
- generate a random response

2/ Slave receives a request and completes it

- receive an address and generate data from it with LFSR
- data are returned if read request
- Check the WDATA matches the expected values
- generate a random response and return it

3/ Master receives the completion

- check response received against the generated one


The drivers can detect the following errors:

- AW request timeout
- W request timeout
- AR request timeout
- R completion error
- BRESP response error
- BUSER error
- BID error
- RRESP response error
- RUSER error
- RDATA error
- RID error
- RLEN error

The monitors can detect the following errors:

- B handshake timeout
- R handshake timeout
- WDATA error
- WLEN error
- ALEN issue
- AWUSER error
- ARUSER error


## Execution

The testbench includes several testcases using the above described scenarios,
limiting the address range target (and so the number of slaves), use on or more
master. The testbench is also setup by different configuration loaded by the
Bash front-end, relying on configuration files. The flow is launched as much
configuration are present in the `tb_config` folder.

To get help and understand all options:

```bash
./run.sh --help

usage: bash ./run.sh ...
     --tc                (optional)            Path to a testbench setup (located in tb_config)
-m | --max-traffic       (optional)            Maximun number of requests injected by the drivers
-t | --timeout           (optional)            Timeout in number of cycles (10000 by default)
     --no-vcd            (optional)            Don't dump VCD file
-h | --help                                    Brings up this menu

```
To run the complete testsuite:

```bash
./run.sh
```
During the execution, 1000 AXI4(-lite) requests are injected into each of the 9 scenarios available.
A default timeout is setup to ensure the whole requests can be completed.

The number of requests can be setup to any value, the user just needs to take
care of the timeout value. The testbench stops after a certain time, even if
the driver/monitor handshake and complete their operations.

A subset of the testbench configuration can also be ran:

```bash
./run.sh --tc tb_config/axi4lite_'*'
```

(Notice the wildcard if used needs to be quoted)
