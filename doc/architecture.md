# Architecture

## Overview


```
                       ┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐
                       │Slave 0│    │Slave 1│    │Slave 2│    │Slave 3│
                       └───────┘    └───────┘    └───────┘    └───────┘
                           ▲            ▲            ▲            ▲
                           │            │            │            │
                           │            │            │            │
    ┌──────────┐           │            │            │            │
    │ Master 0 │─────────▶( )──────────( )──────────( )──────────( )
    └──────────┘           │            │            │            │
                           │            │            │            │
                           │            │            │            │
    ┌──────────┐           │            │            │            │
    │ Master 1 │─────────▶( )──────────( )──────────( )──────────( )
    └──────────┘           │            │            │            │
                           │            │            │            │
                           │            │            │            │
    ┌──────────┐           │            │            │            │
    │ Master 2 │─────────▶( )──────────( )──────────( )──────────( )
    └──────────┘           │            │            │            │
                           │            │            │            │
                           │            │            │            │
    ┌──────────┐           │            │            │            │
    │ Master 3 │─────────▶( )──────────( )──────────( )──────────( )
    └──────────┘
```


A crossbar is a hardware interconnect designed to connect multiple master and slave agents together.
It enables any master to communicate with any slave through a non-blocking switching fabric,
providing high bandwidth and low latency data transfers.  The crossbar implements a fully connected
topology where concurrent transactions can occur between independent master–slave pairs without
interference, as long as they do not target the same destination resources.

The IP is structured into three main layers:

- Slave Interface Layer: This layer receives incoming AXI transactions from slave-side agents (i.e.
  masters in the AXI terminology from the system perspective). It handles protocol adaptation,
  buffering of outstanding requests, and prepares transactions for routing through the interconnect.

- Interconnect Layer: This is the core switching fabric responsible for routing requests to the
  appropriate destination based on address decoding, and routing responses back to the originating
  master using transaction IDs. It ensures non-blocking behavior and fair arbitration between
  competing requests.

- Master Interface Layer: This layer drives outgoing AXI transactions toward master-side agents (i.e.
  slaves in the system). It adapts the routed transactions to the external interface and manages
  response forwarding.


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
    │ │                       Interconnect                       │ │
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


The crossbar is designed as a transparent interconnect: it does not modify transaction contents
(addresses, data, IDs, or sideband signals), but only routes them between endpoints. This modular
architecture allows easy scalability in terms of number of masters/slaves, data width, and protocol
configuration.


## Clock and Reset Network

### Clock

The crossbar relies on a central clock (`aclk`) used by the internal switching fabric. The
performance of the interconnect (latency and throughput) is directly tied to this clock frequency.

Each master and slave interface can operate in its own independent clock domain, with no constraint
on frequency or phase relationship relative to the interconnect clock or other interfaces.

To support this flexibility, optional Clock Domain Crossing (CDC) stages can be enabled on each
interface. These stages safely bridge transactions between the interface clock domain and the
interconnect clock domain.

CDC is implemented using dual-clock FIFOs (DC-FIFO), ensuring reliable data transfer across
asynchronous clock domains while preserving AXI protocol integrity.

If an interface shares the same clock and phase as the interconnect (`aclk`), the CDC stage can be
disabled to reduce latency and area.

### Reset

The crossbar supports both asynchronous and synchronous reset schemes. However, **it is strongly
recommended to use a single reset strategy consistently across the entire design**, including all
connected interfaces.

Two reset signals are available:

- **`aresetn`**: Active-low reset, asynchronously asserted and synchronously deasserted, compliant
  with AMBA AXI recommendations.
- **`srst`**: Active-high reset, fully synchronous to the clock.

If one reset type is unused:
- `aresetn` must be held high permanently
- `srst` must be held low permanently

All reset inputs must be properly driven during reset phases. Leaving reset signals floating or
inconsistently driven may lead to undefined behavior.

Asynchronous reset is commonly preferred in ASIC designs, as it simplifies reset distribution and
timing closure during place-and-route.

Further details can be found in this
[excellent document](http://www.sunburst-design.com/papers/CummingsSNUG2003Boston_Resets.pdf)
from the GOAT: Clifford Cummings.


### Clock Domain Crossing

Each interface can independently enable a CDC stage using the parameters:
- `MSTx_CDC` for master interfaces
- `SLVx_CDC` for slave interfaces

When enabled, transactions are buffered through a DC-FIFO to safely cross into the interconnect
clock domain (`aclk`).

When disabled, the interface is assumed to be synchronous with the interconnect clock, and a
standard synchronous FIFO is used instead.

To ensure correct behavior:
- Interfaces sharing the same clock must also share the same reset
- CDC must be enabled whenever there is any clock frequency or phase difference


### Boot Sequence

To guarantee a clean and deterministic startup of the crossbar, the following initialization
sequence must be respected:

1. Assert all reset signals across the design
2. Start all clock sources for the interconnect and interfaces
3. Wait for several clock cycles in each clock domain to ensure proper reset propagation  (take into
   account slower clock domains)
4. Deassert resets in the following order:
   - First: master interfaces
   - Then: interconnect fabric
   - Finally: slave interfaces

   This sequence minimizes risks of reset domain crossing (RDC) issues and ensures stable AXI
   signaling.

5. Begin issuing transactions only after all domains are fully operational

Failure to follow this sequence may lead to metastability, incomplete reset of internal state
machines, or protocol violations.

## AXI4 / AXI4-lite support


The crossbar supports both **AXI4** and **AXI4-Lite** protocols through a unified and configurable
architecture.

The selected protocol applies globally to the entire interconnect, including all connected master
and slave agents. The crossbar does **not perform any protocol conversion**, therefore all agents
must be configured consistently.

### Configurable Parameters

The following parameters can be configured:

- Address width
- Data width
- ID width
- USER signal width (per channel)

These parameters are shared across the entire crossbar. All connected agents must comply with the
same configuration (e.g., all agents must support the same address and data widths).

All AXI sideband signals (`APROT`, `ACACHE`, `AREGION`, etc.) are transparently propagated through
the interconnect without modification.

The crossbar acts as a **pass-through fabric**, meaning:
- No transformation is applied to transactions
- IDs are not modified
- No reordering optimization is performed beyond AXI requirements


### USER Signal Support

Optional AXI USER signals can be enabled independently for each channel:
- `AUSER`, `WUSER`, `BUSER`, `RUSER`

Each USER field can be configured with a custom width.

If USER signals are disabled, the associated logic is not instantiated, reducing area and
complexity.


### Protocol Consistency

Since the crossbar does not perform protocol adaptation:
- Mixing AXI4 and AXI4-Lite agents requires careful configuration
- AXI4-Lite masters can be connected to an AXI4 system by tying unused signals to `0`
- AXI4-Lite slaves require stricter constraints and must behave according to AXI4-Lite rules

Improper protocol usage may lead to undefined behavior, which is not checked by the crossbar.

### Cache Attributes Handling

The `AxCACHE` signals encode the cacheability and buffering properties of a
transaction, such as bufferable and cacheable behavior, and are primarily
interpreted by memory and coherency-capable components.

The AXI `AxCACHE` attributes are propagated through the crossbar without
modification. These signals are not interpreted or used internally by the
crossbar and are treated as sideband information.

In particular, the crossbar does not implement any cache coherency mechanism
and does not enforce any policy related to cacheability, bufferability, or
allocation attributes conveyed by `AxCACHE`.


### AXI4-lite specificities

AXI4-Lite is a simplified subset of AXI4 with the following characteristics:

- data bus width can be only `32` or `64` bits wide. However, the core
  doesn't perform any checks neither prevent to use another width.

- USER signals are optional and not required by the specification but the core allows to activate
  this feature support.

-  IDs support is not required, but the core supports them natively. This can be helpfull to mix AXI4-lite and
   AXI4 agents together. If not used, the user needs to tied them to `0` to ensure a correct
   ordering model and select a width equals to `1` bit to save area resources.

- Response type `EXOKAY` is not supported in AXI4-Lite. The crossbar does not enforce this
  constraint, and it is the user's responsibility to ensure compliance

All other AXI4 signals not defined in AXI4-Lite are ignored when operating in AXI4-Lite mode.

### Configuration Wizard

A default **4×4 (masters × slaves)** configuration is provided in the `rtl` directory:
- AXI4: `axicb_crossbar_top.sv`
- AXI4-Lite: `axicb_crossbar_lite_top.sv`

For custom topologies, a configuration wizard is available.

#### JSON-based configuration

Users can define a custom configuration file based on existing examples:

```bash
./flow.sh wizard -c ./my_config.json
```

#### TUI-based configuration

An interactive Text User Interface (TUI) is also available:

```bash
./flow.sh wizard --tui
```

The generated configuration includes:
- JSON configuration file
- Corresponding top-level RTL modules

When generating an AXI4-Lite configuration, an AXI4 top-level module is also generated and
instantiated internally.

## Outstanding Requests Support

The core proposes internal buffering capability to serve outstanding requests
from/to the slaves. This can be configured easily for all master and slave
interfaces with two parameters:

- `MSTx_OSTDREQ_NUM` or `SLVx_OSTDREQ_NUM`: the maximum number of oustanding
  requests the core is capable to store
- `MSTx_OSTDREQ_SIZE` or `SLVx_OSTDREQ_SIZE`: the number of datpahases of an
  outstanding requets. Can be useful to save area if a system doesn't need to
  use biggest AXI4 payload possible, i.e. if a processor only use [1,2,4,8,16]
  dataphases maximum. Default should be `256` beats.

When an inteface enables the CDC support to cross its clock domain, the internal
buffering is managed with the [DC-FIFO](https://github.com/dpretet/async_fifo)
instanciated for CDC purpose. If no CDC is required, a simple synchronous FIFO
is used to buffer the requests.

## Ordering rules

The core supports outstanding requests, and so manages traffic queues per master,
this traffic can be:
- in-order if a set of transactions uses the same ID
- out-of-order if a set of transactions uses different IDs

The core doesn't manipulate IDs to enhance the quality-of-service or performing any optimization, so
the user can be sure the read or write requests will be issued to the master interface(s) in the
same order than received on a slave interface.

The core ensures a stream of transactions using the same ID will be completed in-order as stated by
AMBA AXI4 protocol, even if targeting different slaves completing transactions at different paces.
Otherwise, the core will transmit the completion in any order, depending of the slaves response time.

Masters traffic queues are totally uncorrelated into the core, stored in different pieces of logic
without any link.

Read and write traffics are totally uncorrelated, no ordering can be garanteed between the read and
write channels.

The ordering rules mentioned above apply for device or memory regions.


## Routing Accross The Switching Matrix

To route a read/write request to a slave agent, and route back its completion
to a master agent, the core uses the request's address and its ID.

### Requests Routing

Each slave is assigned an address range (`SLVx_START_ADDR` and `SLVx_END_ADDR` address) within the
global memory map. To route a request, the switching logic decodes the address to select the
targeted slave agent, and therefore the corresponding master interface.

For instance, slave agent 0 could be mapped over addresses `0x000` up to `0x0FF`, and the next slave
agent between `0x100` and `0x1FF`. If a request targets an address not mapped to any slave, the
agent will receive a `DECERR` completion.

The user must ensure that the address mapping fits within the address bus width and that there is no
overlap between slave address ranges, as this would lead to misrouting. The core does not check for
such misconfigurations. Memory spaces can be contiguous or not.

### Completions Routing

Each master is identified by an ID mask used to route completions back to it. For
instance, if we suppose the ID field is 8-bit wide, the master agent connected
to slave interface 0 can be configured with the mask `0x10`. If the agent supports
up to 16 outstanding requests, they may span from `0x10` to `0x1F`. The next
agent could be identified with `0x20`, and another one with `0x30`.

The user must ensure that the IDs generated for requests do not conflict with IDs
from another agent, as the ID space is shared. In the setup above, agent 0 cannot
issue IDs greater than `0x1F`, otherwise completions will be misrouted to agent 1.
The core does not check for such misconfigurations. The mask must be greater than 0.

## Switching Logic Architecture

The foundation of the core is made of a switches, one dedicated per interface.
All slave switches can target any master switch to drive read/write requests,
while any master switch can drive back completions to any slave switch.

```

             │                           │
             │                           │
             ▼                           ▼
    ┌─────────────────────────────────────────────┐
    │ ┌──────────────┐           ┌──────────────┐ │
    │ │slv0 pipeline │   .....   │slvX pipeline │ │
    │ └──────────────┘           └──────────────┘ │
    │ ┌──────────────┐           ┌──────────────┐ │
    │ │ slv0 switch  │   .....   │ slvX switch  │ │
    │ └──────────────┘           └──────────────┘ │
    │ ┌──────────────┐           ┌──────────────┐ │
    │ │ mst0 switch  │   .....   │ mstX switch  │ │
    │ └──────────────┘           └──────────────┘ │
    │ ┌──────────────┐           ┌──────────────┐ │
    │ │mst0 pipeline │   .....   │mstX pipeline │ │
    │ └──────────────┘           └──────────────┘ │
    └─────────────────────────────────────────────┘
             │                           │
             │                           │
             ▼                           ▼
```

A pipeline stage can be activated for input and output of the switch layer to
help timing closure.


### Switching Logic from Slave Interfaces

The figure below illustrates the switching logic dedicated to a slave interface.
Each slave interface is connected to such switch which sends requests to master
interface by decoding the address. Completion are routed back from the slave with
a fair-share round robin arbiter to ensure a fair traffic share.

```

                                         From slave interface


       AW Channel                W Channel         B channel         AR Channel        R Channel

           │                        │                 ▲                  │                ▲
           │                        │                 │                  │                │
           │                        │                 │                  │                │
           ▼                        ▼          ┌──────────────┐          ▼         ┌──────────────┐
   ┌──────────────┐   ┌────┐ ┌──────────────┐  │ID Scoreboard │  ┌──────────────┐  │ID Scoreboard │
   │decoder+router│──▶│FIFO│─│    router    │  │   + switch   │  │decoder+router│  │   + switch   │
   └──────────────┘   └────┘ └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
      │        │                │        │        ▲        ▲        │        │        ▲        ▲
      │        │                │        │        │        │        │        │        │        │
      ▼        ▼                ▼        ▼        │        │        ▼        ▼        │        │


                                        To master switches

```

### Switching Logic to Master Interfaces

The figure below illustrates the switching logic dedicated to a master interface.
A fair-share round robin arbitration ensures a fair traffic share from the master and the
completion are routed back to the requester by decoding the ID.

```
                                        From slave switches


   AW Channels               W Channels        B channels        AR Channels      R Channels

   │        │                │        │        ▲        ▲        │        │       ▲         ▲
   │        │                │        │        │        │        │        │       │         │
   ▼        ▼                ▼        ▼        │        │        ▼        ▼       │         │
┌──────────────┐   ┌────┐ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│arbiter+switch│──▶│FIFO│─│    switch    │  │decoder+router│  │arbiter+switch│  │decoder+router│
└──────────────┘   └────┘ └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
        │                         │                 ▲                │                 ▲
        │                         │                 │                │                 │
        ▼                         ▼                 │                ▼                 │


                                        To master interface

```

### Arbitration and Priority Management

Both the master and slave switches use the same arbitration mode, a non-blocking
round-robin model. The behavior of this stage is the following, illustrated here
with four requesters. `req`, `mask` `grant` & `next mask` are 4 bits wide,
agent 0 is mapped on LSB, agent 3 on MSB.

If all requesters are enabled, it will grant the access from LSB to MSB,
thus from req 0 to req 3 and then restart from 0:

```
        req    mask  grant  next mask

t0      1111   1111   0001    1110
t1      1111   1110   0010    1100
t2      1111   1100   0100    1000
t3      1111   1000   1000    1111
t4      1111   1111   0001    1110
t++     ...
```

If the next requester allowed is not active, it passes to the next+2:

```
         req    mask   grant   next mask

t0       1101   1111    0001     1110
t1       1101   1110    0100     1000
t2       1101   1000    1000     1111
t3       1101   1111    0001     1110
t4       1111   1110    0010     1100
t5       1111   1100    0100     1000
t++   ...
```

If a lonely request doesn't match a mask, it passes anyway and reboot the
mask:

```
         req    mask  grant   next mask

t0       0011   1111   0001     1110
t1       0011   1110   0010     1100
t2       0011   1100   0001     1110
t3       0111   1110   0010     1100
t4       0111   1100   0100     1000
t++      ...
```

To balance granting, masters can be prioritzed (from 0 to 3). An activated
highest priority layer prevent computation of lowest priority layers (here,
priority 2 for req 2, 0 for others):

```
         req    mask   grant   next mask (p2) next mask (p0)

t0       1111   1111    0100      1000          1111
t1       1011   1111    0001      1100          1110
t2       1011   1110    0010      1100          1100
t3       1111   1000    0100      1111          1100
t4       1011   1100    1000      1111          1111
t++      ...
```


### Shareability & Routing Tables

Each master can be configured to use only specific routes across the crossbar
infrastructure. This feature, if used, can help reduce gate count, as it restricts
portions of the memory map to certain agents, for security reasons or to avoid
any accidental memory corruption. **By default, a master can access any
slave**.

The parameter `MSTx_ROUTES` of N bits enables or disables a route. Bit `0`
enables routing to slave agent 0 (master interface 0), bit `1` to slave agent 1,
and so on. This setup physically isolates agents from each other and cannot be
overridden once the core is implemented.

If a master agent tries to access a restricted region of the memory map, its
slave switch will handshake the request, will not forward it, and will then
complete the request with a `DECERR`.

This option can be used to define whether memory regions are shared or isolated
between master agents, allowing controlled access to common resources (e.g. shared
memory) or strict partitioning when required for safety, security, or data integrity.
