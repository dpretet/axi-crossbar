# Feature: Deadlock & Cyclic Dependency Avoidance (DCDA)

## 1. Introduction

This feature is the continuation of #9 dev which enforced the ID ordering rules for completion.
Before #9 was completed, a master sending two requests with the ID to two different slaves wasn’t
ensured to receive the completion in the right order. By using an ID scoreboard on the slave switch,
tracking the transaction attributes and the slave targeted, the completion flow now routes correctly
the read / write completion bursts.

However, this development didn’t handle a problem every interconnect suffers: cyclic dependency. A
cyclic dependency occurs when multiple transactions between masters and slaves block each other due
to the order in which the read and write channels (R and B channels) must complete.

Specifically, a dependency cycle appears when:
1. A master is waiting for the completion of a transaction to be able to release or issue the next one.
2. That completion itself is blocked by a transaction coming from another master.
3. The other master is in turn blocked by the first one, forming a closed loop.

Formally:
```
Resource A waits for Resource B
Resource B waits for Resource C
...
Resource N waits for Resource A
```

In hardware interconnects, "resources" typically include:
- internal buffers (FIFOs)
- arbitration grants
- switchs
- target ports (slaves)
- protocol ordering constraints

Typical example with two masters and two slaves:
* M0 sends a write to S0 and then to S1.
* M1 sends a write to S1 and then to S0.
* S0 waits to finish the transaction with M1 to free its resources.
* S1 waits to finish the transaction with M0.

In this situation, each element waits for the other to release: none can progress, creating a deadlock.

In an AXI crossbar or fabric, these cycles can occur if:
* The per-ID buffers are saturated.
* The routing of the completion channels (B and R) is blocked.
* Masters reuse the same ID for requests to different slaves.

Handling cyclic dependencies requires either:
* Prevention: sizing and routing policies that avoid forming a cycle. QoS arbitration and VCs are
  the most solution. Not the solution chosen for this development
* Detection: mechanisms to break the cycle, for example by deprioritizing certain transactions or
  forcing a flush.

The current architecture also doesn’t handle  a problem which is not formally a cyclic dependency
issue but a temporal coherence issue:

- A master M0 issues a write request to the slave S0 to store a for instance a descriptor
- Then it writes to the slave S1 a register to start an operation

If the slave S0 is very slower than slave S1, or if it’s occupied by a current transfer or an
internal operation, the register could be written before the descriptor, and most likely corrupt the
operation to execute with the system. The same solution will be applied to address this problem.

## Resources
- https://www.youtube.com/watch?v=2r-tLn6BPy0
- https://www.youtube.com/watch?v=zqsFDPEJy0Q
- https://www.youtube.com/watch?v=FHUstUP-6_8&t=8s
- https://developer.arm.com/documentation/ddi0475/c/functional-description/operation/cyclic-dependency-avoidance-schemes--cdas-
