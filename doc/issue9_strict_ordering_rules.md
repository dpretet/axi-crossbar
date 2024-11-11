# Strict Ordering Rules Support

## Overview

The first implementation of the crossbar didn't ensure a correct ordering of write and read
response. Indeed, in order to simplify the implementation, the slave switch module just forward
request and completion in the order a master issues and a slave completes, whatever the ID used.
This makes the completion routed back to the master out-of-order if the request used multiple times
the same ID across two or more slaves which are not completing at the same pace. Moreover, this core
has been designed for a RISCV processor which couldn't target multiple slaves because using a single
RAM instance, and use always the same ID.

To enhance the crossbar and its ordering rules support, this development will upgrade the slave
switch module to ensure the completion ordering correct among the same ID queue.

## Design Plan

Each slave switch will now embbed a FIFO for each ID, as much FIFO than outstanding request
supported, with a depth equals to the the number of outstanding request supported. This FIFO will
store the slave index targeted by the requests using the same ID.

While each master is identified by its unique ID Mask, the number of FIFO could be huge. Indeed,
the user must extend the ID width and these extra bits would widely increase the possible ORs.
So the slave switch slave will always decode/remove the mask to instance a minimum number of FIFOs.

The switch will no more support completion interleaving, i.e. a read completion will be
now completely routed-back the master until RLAST assertion. This feature is not so usefull
and may be complicated to support for a master.

The switch will no more use a round-robin arbitration to route-back the completion but simply
empty the FIFO's ID one by one, in-order.

## Verification

- Use the existing testbench driving randomized request
- Unleash master drivers to issue multiple consecutive outstanding requets with the same ID
