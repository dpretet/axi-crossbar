# AMBA AXI Crossbar

[![GitHub license](https://img.shields.io/github/license/dpretet/axi-crossbar)](https://github.com/dpretet/axi-crossbar/blob/master/LICENSE)
![Github Actions](https://github.com/dpretet/axi-crossbar/actions/workflows/ci.yaml/badge.svg)
[![GitHub issues](https://img.shields.io/github/issues/dpretet/axi-crossbar)](https://github.com/dpretet/axi-crossbar/issues)
[![GitHub stars](https://img.shields.io/github/stars/dpretet/axi-crossbar)](https://github.com/dpretet/axi-crossbar/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/dpretet/axi-crossbar)](https://github.com/dpretet/axi-crossbar/network)


## Overview

An AXI4 crossbar implemented in SystemVerilog to build the foundation of a SOC.

A crossbar is a circuit connecting multiple master and slave agents, mapped
across a memory space. The core consists of a collection of switches, routing
the master requests to the slaves and driving back completions to the agents.
A crossbar is a common piece of logic to connect in a SOC the
processor(s) with the peripherals like memories, IOs, co-processors...


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
- CDC support in master & slave interface, to convert an agent clock domain
  from/to the fabric clock domain
- Round-robin fair-share arbitration
    - Non-blocking arbitration between requesters
    - Priority configurable per master interface
- AXI or AXI4-Lite mode:
    - LITE mode: route all signals described in AXI4-lite specification
    - FULL mode: route all signals described by AXI4 specification
    - The selected mode applies to the global infrastructure
- Routing table can be defined to restrict slaves access
    - Easily create enclosed and secured memory map
    - Dedicate sensitive slaves only to trusted master agents
- USER signal support
    - Configurable for each channel (AW, AR, W, B, R)
    - Common to all master/slave interfaces if activated


## Implementation Details

- Interfaces share the same address / data / ID width
    - Address width configurable, any width
    - Data width configurable, any width
    - ID width configurable, any width
- Advanced clock/reset network
    - Support both asynchronous and synchronous reset schemes
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
- Don't garantee completion ordering when a master targets multiple slaves with the
  same AXI ID (!). A master should use different IDs and reorder the completion by itself

Further details can be found in:
- The architecture [chapter](doc/architecture.md)
- The IOs/parameters [chapter](doc/io_parameter.md)


## Verification environment

The core is verified with a testbench relying on pseudo-random driver and
monitor to inject some traffic and verify its correctness. Please refer to the
[dedicated chapter](./test/svut/README.md) for futher details and find hints
to integrate the core in your own development. The flow relies on:

- [Icarus Verilog 11](https://github.com/steveicarus/iverilog) as simulator
- [SVUT](https://github.com/dpretet/svut) to configure and execute Icarus


## Development plan

Core features:
- Full AXI ordering support: put in place multiple queues
  per ID and manage reordering to master interfaces
- Read-only or write-only master to save gate count
- Address translation service to connect multiple systems together
- Timeout support in switching logic
- Debug interface to steam out events like 4KB crossing or timeout

Wizard:
- Number of master and slave agents configurable
- RTL generator

AXI Goodies:
- Interface datapath width conversion
- AXI4-to-AXI4-lite converter
    - split AXI4 to multiple AXI4-lite requests
    - gather AXI4-lite completion into a single AXI completion
- 4KB boundary crossing checking, supported by a splitting mechanism

Simulation:
- Support Verilator
- Error injection in the core and tesbench
- Implement statistics in testbench to track misrouting, address distribution,
  master granting, ...
- New Checkers:
    - Check address overlap (start+end vs next slave start address)
    - ID overlap: mask ID + OR number supported up to next slave ID

## License

This IP core is licensed under MIT license. It grants nearly all rights to use,
modify and distribute these sources.

However, consider to contribute and provide updates to this core if you add
feature and fix, would be greatly appreciated :)
