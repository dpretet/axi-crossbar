# AMBA AXI Crossbar

## Overview

An AXI4 crossbar implemented in SystemVerilog to build the foundation of a SOC.

A crossbar is a circuit connecting multiple master and slave agents, mapped
across a memory space. The core consists of a collection of switches, routing
the master requests to the slaves and driving back completions to the agents.
A crossbar is a common piece of logic to connect for instance in a SOC the
processor(s) with its peripherals like memories, IOs, co-processors...


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
    - Outstanding request number and payload configurable
    - Seamless support of AXI4 vs AXI4-lite
- CDC support in master & slave interface. Convert an interface's clock domain
  from/to the crossbar inner clock domain
- Round-robin fair share
    - Non-blocking arbitration between requesters
    - Priority configurable per master interface
- Timeout support, configurable per agent interface
- AXI or AXI4-Lite mode:
    - LITE mode: route all signals described in AXI4-lite specification
    - FULL mode: route all signals described by AXI4 specification
    - The selected mode applies to global infrastructure
- Masters routing can be defined to restrict slaves access
    - Easily create enclosed and secured memory map
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
  into the memory space across a start/end address range.
- Route read & write completion by ID decoding. All master agents have an ID
  mask used to identified the route to drive back a completion
- Configurable routing across the infrastructure
    - A master can be restricted to a memory map subset
    - An acccess to a forbidden area is completed by a DECERR
- Switching logic IO interfaces can be pipelined to achieve timing closure easier

Further details can be found in:
- the architecture [chapter](doc/architecture.md)
- the IOs/Parameters [chapter](doc/io_parameter.md)


## Verification environment

The core is verified with a testbench relying on (pseudo) random driver and
monitor to inject some traffic and verify its correctness. Please refer to the
[dedicated chapter](./test/svut/README.md) for futher details and find hints
to integrate the core in your own development. The flow relies on:

- [Icarus Verilog 11](https://github.com/steveicarus/iverilog) as simulator
- [SVUT](https://github.com/dpretet/svut) to configure and execute Icarus


## Development plan

Limitations (current dev stage)

- No timeout support

Inbox (possible next devs)

- Error injection in the core and tesbench
- Implement statistics in testbench to track misrouting, address distribution,
  master granting, ...
- New Checkers:
    - Check address overlap (start+end vs next slave start address)
    - Check address range bigger than address bus width
    - ID overlap: mask ID + OR number supported up to next slave ID
- Address translation service
- Number of master and slave agents configurable
- RTL generator to support any number of master / slave agents
- Completion reordering to support of out-of-order responses
- Interface datapath width conversion
- AXI4/AXI4-lite converter
- Read-only or Write-only master to save gate count
- Full-STRB vs Partial-STRB mode
    - Partial-STRB mode stores only first and last phase of a write request's payload STRBs,
      all other dataphases are fully activated (WSTRBs=1)
    - Full-STRB mode transports the complete STRBs dataphases as driven by a master
    - Useful to save gate count
- 4KB boundary crossing checking, supported by a splitting mechanism


## License

This IP core is licensed under MIT license. It grants nearly all rights to use,
modify and distribute these sources.

However, consider to contribute and provide updates to this core if you add
feature and fix, would be greatly appreciated :)
