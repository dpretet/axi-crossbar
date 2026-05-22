# Feature: Cyclic Dependency Avoidance (CDA)

## 1. Introduction

This feature is the continuation of #9 dev which enforced the ID ordering rules for completion.
Before #9 was completed, a master sending two requests with the same ID to two different slaves wasn’t
ensured to receive the completion in a consistent order when transactions with the same ID were
issued to different slaves. By using an ID scoreboard on the slave switch, tracking the transaction
attributes and the targeted slave, the completion flow now correctly routes the read / write
completion bursts.

However, this development didn’t handle a problem every interconnect suffers from: cyclic dependency. A
cyclic dependency occurs when multiple transactions between masters and slaves block each other due
to the order in which the read and write channels (R and B channels) must complete.

## 2. Problem

A dependency cycle appears when:
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
- switches
- target ports (slaves)
- protocol ordering constraints

Cyclic dependencies only manifest in the presence of finite buffering and backpressure, which are
inherent to practical hardware implementations. While increasing buffering depth may reduce the
likelihood of such situations, it does not eliminate the fundamental risk of deadlock, as resource
dependency cycles can still form under sustained traffic patterns. Consequently, the interconnect
architecture must be designed to prevent these cyclic dependencies by construction, rather than
relying on buffering to absorb them.

## 3. Example

Typical example with two masters and two slaves:

* M0 issues a write to S0 (ID = X), then a write to S1 (ID = X).
* M1 issues a write to S1 (ID = Y), then a write to S0 (ID = Y).

* The interconnect and/or slaves have limited buffering for outstanding transactions.

* S0 cannot accept the transaction from M1 because its resources are occupied (e.g., waiting for completion path availability).
* S1 cannot accept the transaction from M0 for the same reason.

* Completion paths (B channel) are backpressured due to internal resource dependencies.

Because blocked transactions remain at the head of the queue, they prevent subsequent transactions
from progressing. This head-of-line blocking propagates backpressure across the interconnect and
closes a dependency loop. Each element waits for others to release, and no forward progress is
possible, resulting in a deadlock.

In an AXI crossbar or fabric, these cycles can occur if:
* The per-ID buffers are saturated.
* The routing of the completion channels (B and R) is blocked.
* Masters reuse the same ID for requests to different slaves.

Handling cyclic dependencies requires either:
* Prevention: sizing and routing policies that avoid forming a cycle. QoS arbitration and VCs are
  the most common, advanced solutions. Not the solution chosen for this development.
* Detection: mechanisms to break the cycle, for example by deprioritizing certain transactions or
  forcing a flush.

The current architecture still suffers from an ordering hazard, which is not formally a cyclic dependency
issue but a temporal coherence issue from a master point of view:

- A master M0 issues a write request to the slave S0 to store, for instance, a descriptor.
- Then it writes to the slave S1 a register to start an operation.

If the slave S0 is much slower than slave S1, or if it is occupied by a current transfer or an
internal operation, the register could be written before the descriptor, and most likely corrupt the
operation to be executed by the system. The same solution will be applied to address this problem
while enforcing write ordering.

## 4. DCDA Policy: Single-Slave-Per-ID Constraint

To prevent cyclic dependencies and guarantee forward progress, the interconnect introduces a
constraint on how transactions sharing the same ID are issued.

### Principle

For a given ID, transactions are restricted to target only one slave at a time.

- If no transaction with this ID is outstanding:
    - a new transaction can be issued to any slave.

- If a transaction with this ID is already in flight:
    - any new transaction with the same ID targeting a different slave is stalled at the Slave
      Switch.
    - transactions targeting the same slave remain allowed.

### Behavior

The Slave Switch tracks, for each active ID, whether it is currently in use, and the associated
target slave. A new request (AW/AR) is accepted only if the ID is free, or the ID is already
associated with the same target slave.

The ID is released when:

- the corresponding write response (BVALID) is received, or
- the last read data beat (RLAST) is received.

### Guarantees

This policy ensures that:

No cyclic dependency can be formed across multiple slaves for a given ID. Completion paths (R and B
channels) cannot be mutually blocked due to inter-slave ordering constraints. Forward progress is
always guaranteed.
