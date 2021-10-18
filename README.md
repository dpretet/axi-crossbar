# AXI Crossbar

## Overview

An AXI4 crossbar implementation in SystemVerilog

Features

- Number of master and slave configurable, maximum 8x8 m/s
- Master/slave buffering configurable per interface
    - Outstanding request number configurable per interface
    - Request payload configurable per interface (AXI3 vs AXI4 vs AXI4-lite seamless support)
- CDC support per master/slave interface
- Round-robin arbitration
    - non-blocking balance between requesters
    - priority configurable per master interface
- Timeout support per AXI4 channel & per interface (shared counter configurable)
- Pipeline stage configurable for input & output of the interconnect
- Full-STRB storage or contiguous-only/partial STRB for first and last phase only
- USER signal support, optional but impact all interfaces
- FULL, RESTRICTED and LITE modes for the crossbar infrastructure to save gate count
    - LITE mode: all signals described in AXI4-lite specification
    - FULL mode: all signals described by AXI4 specification (PROT, CACHE, REGION, QOS, ...)
    - RESTRICTED mode: only an AXI4 subset, for application needing to do simple
      memory-mapped requests (AXI4-lite with burst mode capability)

Implementation

- All interfaces share the same address / data width
- Routing with address decoding from master to slave
- Routing done by ID from slave to master
- Use pass-thru buffering stage to optimize both latency and interconnect avaibility

## Development plan

Limitations (current dev stage)

- no interface buffering
- no CDC stage
- no master priority setup
- 4x4 master/slave interfaces
- Full-STRB mode only
- LITE mode only
- no USER signals support
- AW & W channels need to be ready at the same cycle
- No completion ordering management, may be completed to masters out-of-order

Inbox

- Number of master/slave configurable, wider than 8x8
- Interface width adaptation
- Can support traffic reordering in case of out-of-order completion
- 4KB boundary crossing check
