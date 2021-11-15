# AXI Crossbar

## Overview

An AXI4 crossbar implemented in SystemVerilog to build the foundation of a SOC.

A crossbar is a circuit connecting multiple master and slave agents, mapped
across a memory space. The core consists of a collection of switches, routing
the master requests to the slaves and driving back completions to the agents.
A crossbar is common piece of logic to connect for instance in a SOC the
processor(s) with the peripherals like memories, IOs, coprocessors...


```
    ┌─────────────┬───┬──────────────────────────┬───┬─────────────┐
    │             │ S │                          │ S │             │
    │             └───┘                          └───┘             │
    │ ┌───────────────────────────┐  ┌───────────────────────────┐ │
    │ │      Slave Interface      │  │      Slave Interface      │ │
    │ └───────────────────────────┘  └───────────────────────────┘ │
    │               │                              │               │
    │               ▼                              ▼               │
    │ ┌──────────────────────────────────────────────────────────┐ │
    │ │                         Crossbar                         │ │
    │ └──────────────────────────────────────────────────────────┘ │
    │               │                              │               │
    │               ▼                              ▼               │
    │ ┌───────────────────────────┐  ┌───────────────────────────┐ │
    │ │     Master Interface      │  │     Master Interface      │ │
    │ └───────────────────────────┘  └───────────────────────────┘ │
    │             ┌───┐                          ┌───┐             │
    │             │ M │                          │ M │             │
    └─────────────┴───┴──────────────────────────┴───┴─────────────┘
```


Features

- 4x4 master/slave interfaces
- Master/slave buffering capability, configurable per interface
    - Outstanding request number configurable
    - Request payload configurable per interface (AXI3 vs AXI4 vs AXI4-lite seamless support)
- CDC support in master & slave interface. Convert an interface's clock domain
  from/to the crossbar inner clock domain
- Round-robin arbitration
    - Non-blocking arbitration between requesters
    - Priority configurable per master interface
- Timeout support per AXI channel & per interface
- Switching logic IO interfaces can be pipelined to achieve timing closure easier
- Full-STRB vs Partial-STRB mode
    - Partial-STRB mode stores only first and last phase of a write request's payload STRBs,
      all other dataphases are fully activated (WSTRBs=1)
    - Full-STRB mode transports the complete STRBs dataphases as driven by a master
    - Useful to save gate count
- AXI or AXI4-Lite mode:
    - LITE mode: route all signals described in AXI4-lite specification
    - FULL mode: route all signals described by AXI4 specification
    - The mode applies to global infrastructure
- Master routes to a slave can be defined to restrict slave access
    - Permits to create enclosed and secured memory map
    - Access a forbidden memory zone returns a DECERR reponse in completion channel
    - Useful to save gate count
- USER signal support
    - Configurable for each channel (AW, AR, W, B, R)
    - Common to all master/slave interfaces if activated


## Implementation Details

- Interfaces share the same address / data / ID width
    - Address width configurable, any width
    - Data width configurable, any width
    - ID width configurable, any width
- Advanced clock/reset network
    - Support both aynchronous and synchronous reset schema
    - Can handle clock domain crossing if needed, the core being fueled by its
      own clock domain
- Route read/write requests by address decoding. All slave agents are mapped
  into the memory space with a start/end address range.
- Route read & write completion by ID decoding. All master agents have an ID
  mask used to identified the route to drive back a completion
- Configurable routing across the infrastructure
    - A master can be restricted to a memory map subset
    - An acccess to a forbidden area is completed by a DECERR
- Timeout behaves as following:
    - A shared counter implements a millisecond / microsecond time reference,
      configurable based on the platform clock speed
    - A request timeout leads the completion to response with SLVERR
    - A completion timeout leads the switching logic circuit to empty the
      completer response (up to RLAST assertion for the R channel, else simply
      handshake the B channel)

Futher details can be found in the architetcure [chapter](doc/architecture.md) 
and the IO/Parameter [chapter](doc/io_paremeter.md)

## Development plan

Limitations (current dev stage)

- No timeout support
- No master routing tables
- Full-STRB mode only

Inbox (possible next devs)

- Address translation service
- Number of master and slave agents configurable
- RTL generator to support any number of master / slave agents
- Completion reordering to support of out-of-order responses
- Interface datapath width conversion
- AXI4/AXI4-lite converter
- Read-only or Write-only master to save gate count
- 4KB boundary crossing checking, supported by a splitting mechanism


## License

This IP core is licensed under MIT license. It grants nearly all rights to use,
modify and distribute these sources.

However, consider to contribute and provide updates to this core if you add
feature and fix, would be greatly appreciated :)
