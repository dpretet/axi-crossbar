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


A crossbar is a piece of logic aiming to connect any master to any
slave connected upon it. Its interconnect topology provides a low latency, high
bandwidth switching logic for a non-blocking, conflict-free communication flow.

The IP can be divided in three parts:
- the slave interface layer, receiving the requests to route
- the interconnect layer, routing the requests
- the master interface layer, driving the requests outside the core


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

Master and slave interfaces are mainly responsible to support the oustanding
requests and prepare the AXI request to be transported through the switching
logic. The interconnect is the collection of switches routing the requests and
the the completions from/to the agent.


## Clock and Reset Network

## Clock

The core uses and needs a reference clock for the internal switching logic. The
higher the frequency is, the better will be the global bandwidth and latency
of the system.

Each interface can operate in its own clock domain, whatever the frequency and
the phase regarding the other clocks. The core proposes a CDC stage for each
interface to convert the clock to the interconnect clock domain. The CDC stage
is implemented with a [DC-FIFO](https://github.com/dpretet/async_fifo).

The user can also use the same clock for all the interfaces. In this
configuration, all the agents connected to the core have to use the same clock
than the interconnect switching logic.

## Reset

The core fully supports both asynchronous and synchronous reset. The choice
between these two options depends to the technology targeted. Most of the time,
asynchronous reset schema is the prefered option. It is STRONGLY ADVICED TO
NOT MIX THESE TWO RESET TYPES, and choose for instance asynchronous reset only
for the core and ALL the interfaces. The available resets, named uniformly
across the interfaces, are:

- `aresetn`: active low reset, asynchronously asserted, synchronously deasserted
  to the clock, compliant with AMBA requirement.
- `srst`: active high reset, asserted and deasserted synchronously to the clock.

If not used, `srst` needs to remain low; if not used, `aresetn` needs to
remain high all the time.

Asynchronous reset is the most common option, especially because it simplifies
the efforts of the PnR and timing analysis steps.

Further details can be found in this
[excellent document](http://www.sunburst-design.com/papers/CummingsSNUG2003Boston_Resets.pdf)
from the excellent Clifford Cummings.


## AXI4 / AXI4-lite support

The core supports both AXI4 and AXI4-lite protocol by a single parameter setup.
For both protocols, the user can configure:
- the address bus width
- the data bus width
- the ID bus width
- the USER width, per channel

The configurations apply to the whole infrastructure, including the agents.
An agent connected to the core must support for instance `32` bits addressing if
other ones do. All other sideband signals (APROT, ACACHE, AREGION, ...) are
described and transported as the AMBA specification defines them. No modification
is applied by the interconnect on any signal, including the ID fields. The
interconnect is only a pass-thru infrastructure which transmits from one point
to another the requests and their completions.

A protocol support applies to the global architecture, thus the agents connected.
The core doesn't support (yet) any protocol conversion. An AXI4-lite agent could
be easily connected as a master agent by mapping the extra AXI4 fields to `0`.
However, connecting it as a slave agent is more tricky and the user must ensure
the ALEN remains to 0 and no extra information as carried for instance by ACACHE
is needed.

Optionally, AMBA USER signals can be supported and transported (AUSER, WUSER,
BUSER and RUSER). These bus fields of the AMBA channels can be activated
individually, e.g. for address channel only and configured to any width. This
applies for both AXI4 and AXI4-lite configuration.

### Ordering rules

The core supports outstanding requests, and so manages traffic queues. However,
the core doesn't support reodering to enhance traffic and so the user can be
sure the read or the write requests will be issued to the master interface(s)
in the same order than received on a slave interface.

Read and write traffic are totally uncorrelated, no ordering can be garanteed
between the read / write channels.

The odering rules mentioned above are applicable only on a slave interface, and
so concurrent slaves traffic can be served in a different way than the requests
are received.

The odering rules mentioned above imply device or memory regions accesses are
managed in the same way.

### AXI4-lite specificities

AXI4-lite specifies the data bus width can be only `32` or `64` bits wide.
However, the core doesn't perform any checks neither prevent to use another
width. The user is responsible to configure his platform with values according
the specification.

AXI4-lite doesn't request USER fields but the core allows to activate this
feature support.

AXI4-lite doesn't request IDs support, but the core supports them natively.
The user can use them or not but they are all carried across the
infrastructure.  This can be helpfull to mix AXI4-lite and AXI4 agents
together. If not used, the user needs to tied them to `0` to ensure a correct
ordering model and select a width equals to `1` bit to save area resources.

AXI4-lite doesn't support RESP with value equals to `EXOKAY` but the core
doesn't check that. The user is responsible to drive a completion with a
correct value according the specification.

AXI4-lite supports WSTRB and the core too. It doesn't manipulate this field and
the user is responsible to drive correctly this field according the
specification.

AXI4-lite doesn't support LAST signals. The core handles them internally for
its own purpose and the user doesn't need to take care of them. The user can
tied them to `0` or `1` or leave them unconnected.

All other fields specified by AXI4 and not mentioned in this section are not
supported by the core when AXI4-lite mode is selected. They are not used
neither carried across the infrastructure and the user can safely ignore them.


## Outstanding Requests Support

The core proposes internal buffering capability to serve outstanding requests
from/to the slaves. This can be configured easily for all master and slave
interfaces with two parameters:

- `MSTx_OSTDREQ_NUM` or `SLVx_OSTDREQ_NUM`: the maximum number of oustanding
  requests the core is capable to store
- `MSTx_OSTDREQ_SIZE` or `SLVx_OSTDREQ_SIZE`: the number of datpahases of an
  outstanding requets

When an inteface enables the CDC support to cross its clock domain, the internal
buffering is managed with the [DC-FIFO](https://github.com/dpretet/async_fifo)
instanciated for CDC purpose. If no CDC is required, a simple synchronous FIFO
is used to buffer the requests.

## Routing Accross The Switching Matrix

To route a read/write request to a slave agent, and route back its completion
to a master agent, the core uses the request's address and its ID.

Each master is identified by an ID mask to route back completion to it. For
instance if we suppose the ID field is 8 bit wide, the master agent connected
to the slave interface 0 can be setup with the mask `0x10`. If the agent supports
up to 16 outstanding requests, they may span between `0x10` and `0x1F`. The next
agent could be identified with `0x20` and another one with `0x30`. The user must
takes care the ID generated for a request doesn't conflict with an ID from
another agent, thus the ID numbering rolls off. In the setup above, the agent 0
can't issue ID bigger than `0x1F` which will mis-route completion back to it and
route it to the agent 1. The core doesn't track such wrong configuration. The
must use a mask greater than 0.

Each slave is assigned into an address map (start & end address) across the
global memory map. To route a request, the switching logic decodes the address
to select the slave agent targeted and so the master interface to source. For
instance, slave agent 0 could be mapped over the addresses `0x000` up to
`0x0FF`. Next slave agent between `0x100` and `0x1FF`. In case the request
tries to target a memory space not mapped to a slave, the agent will receive a
`DECERR` completion. The user must ensure the address mapping can be covered
by the address bus width; the user needs to take care to configure correctly
the mapping and avoid any address overlap between slaves which will lead to
mis-routing. The core doesn't track such wrong configurations.


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
│ │ slv0 switch  │           │ slv1 switch  │ │
│ └──────────────┘           └──────────────┘ │
│                                             │
│ ┌──────────────┐           ┌──────────────┐ │
│ │ mst0 switch  │           │ mst1 switch  │ │
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
a round robin arbitrer to ensure a fair traffic share. This architecture
doesn't ensure any ordering rule and the master is responsible to reorder its
completion if needed by its internal core.

```

                                     From slave interface


   AW Channel                 W Channel         B channel         AR Channel        R Channel

        │                         │                 ▲                  │                ▲
        │                         │                 │                  │                │
        ▼                         ▼                 │                  ▼                │
┌──────────────┐   ┌────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│decoder+router│──▶│FIFO│──│decoder+router│  │arbiter+switch│  │decoder+router│  │arbiter+switch│
└──────────────┘   └────┘  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
   │        │                 │        │        ▲        ▲        │        │        ▲        ▲
   │        │                 │        │        │        │        │        │        │        │
   ▼        ▼                 ▼        ▼        │        │        ▼        ▼        │        │


                                    To master switches
```

### Switching Logic to Master Interfaces

The figure below illustrates the switching logic dedicated to a master interface.
A round robin arbitration ensures a fair traffic share from the master and the
completion are routed back to the requester by decoding the ID.

```
                                    From slave switches


   AW Channels       W Channels        B channels        AR Channels        R Channels

   │        │        │        │        ▲        ▲        │        │        ▲        ▲
   │        │        │        │        │        │        │        │        │        │
   ▼        ▼        ▼        ▼        │        │        ▼        ▼        │        │
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│arbiter+switch│  │arbiter+switch│  │arbiter+switch│  │decoder+router│  │decoder+router│
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
        │                 │                 ▲                │                 ▲
        │                 │                 │                │                 │
        ▼                 ▼                 │                ▼                 │


                                    To master interface

```

### Arbitration and Priority Management

Both the master and slave switches use the same arbitration mode, a non-blocking
round robin model. The behavior of this stage is the following, illustrated here
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
t++      1111   1100    0100     1000
      ...
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


### Sharability & Routing Tables

Each master can be configured to use only specific routes across the crossbar
infrastructure. This feature if used can help to save gate count as will
restrict portion of the memory map to certain agents, for security reasons or
avoid any accidental memory corruption. **By default a master can access to any
slave**. The parameter `MSTx_ROUTES` of N bits enables or not a route. Bit `0`
enable to route to the slave agent 0 (master interface 0), bit `1` to the slave
agent 1 and so on. This setup physically isolates agents from each others and
can't be overridden once the core is implemented. If a master agent tries to
access a restricted zone of the memory map, its slave switch will handshake the
request, will not transmit it and then complete the request with a `DECERR`.

This option can be use to define memory region sharable or not between master
agents.

### Timeout Events Handling

Timeout detection and management can be enabled and configured by interface.
This avoids any deadlock if a slave doesn't respond to a request, or if a
master doesn't accept a completion.

A pair of shared counters implement millisecond / microsecond time references,
configurable based on the platform clock speed. A request or completion may occur
once the low precision timer (us timer) started a new epoch, making the timeout
more or less precise. The user needs to adjust its values to take in account this
implementation, chosen to lower gate count.

Timeout is handled as following:
- A request timeout leads the completion to response with `SLVERR`. The slave
  switch logic handshakes with the connected master agent to completly terminate
  the request. This concerns either write address/data channel or read address
  channel.
- A completion timeout leads the switching logic circuit to empty the
  completer response (up to RLAST assertion for the R channel). This concerns
  write response channel and read data channel.

The core's behavior ensures the agents can continue to operate, but can't ensure
the whole system will still be operational. The user needs to correctly manage
these situations.
