# AXI Crossbar

## Overview

An AXI4 crossbar implemented in SystemVerilog to build the foundation of a SOC.

- Number of master and slave configurable
- Master/slave buffering capability, configurable per interface
    - Outstanding request number configurable
    - Request payload configurable per interface (AXI3 vs AXI4 vs AXI4-lite seamless support)
- CDC support in master & slave interface. Convert an interface's clock domain
  from/to the crossbar inner clock domain
- Round-robin arbitration
    - Non-blocking arbitration between requesters
    - Priority configurable per master interface
- Timeout support per AXI channel & per interface
    - A shared counter implement a time reference
    - A request timeout leads the completion to response with DECERR
    - A completion timeout leads the completion to response with SLVERR
- Switching logic IO interfaces can be pipelined to achieve timing closure easier
- Full-STRB vs Partial-STRB mode
    - Partial-STRB mode stores only first and last phase of a write request's payload STRBs,
      all other dataphases are fully activated (WSTRBs=1)
    - Full-STRB mode transports the complete STRBs dataphases as driven by a master
    - Useful to save gate count
- USER signal support
    - Configurable for each channel (AW, AR, W, B, R)
    - Common to all master/slave interfaces if activated
- FULL, RESTRICTED and LITE AXI modes
    - LITE mode: route all signals described in AXI4-lite specification
    - FULL mode: route all signals described by AXI4 specification
    - RESTRICTED mode: route only an AXI4 subset, for application needing to do simple
      memory-mapped requests (AXI4-lite being burst capable)
    - Useful to save gate count
- Master routes to a slave can be defined to restrict slave access
    - Permits to create enclosed and secured memory map
    - Access a forbidden memory zone returns a DECERR reponse in completion channel
    - Useful to save gate count

## Implementation Details

- All interfaces share the same address / data / ID width
    - Address width configurable, any width
    - Data width configurable, any width
    - ID width configurable, any width
- Route read/write requests by address decoding. All slaves are mapped into
  the memory space with a start/end address range.
- Route read & write completion by ID decoding. All masters have an ID mask
  used to identified the route to drive back a completion

## Development plan

Limitations (current dev stage)

- 4x4 master/slave interfaces
- LITE mode only (AXI4 mode should work, juest not tested yet)
- no master priority setup
- no timeout support
- Full-STRB mode only
- no xUSER signals support
- AW & W channels need to be ready at the same cycle

Inbox

- Top level generator to adapt the core to the users need
- AXI4/AXI4-lite converter
- Read-only or Write-only master to save gate count
- Number of master/slave configurable, wider than 8x8
- Interface datapath width conversion
- Completion reordering in case of out-of-order response
- 4KB boundary crossing checking
- Address translation service
