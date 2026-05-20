# Feature: Cyclic Dependency Avoidance (CDA)


## 1. Introduction

Modern AXI-based interconnects support multiple outstanding transactions, out-of-order completion, and independent channels (AW, W, B, AR, R).
While these features enable high performance, they also introduce the possibility of **cyclic resource dependencies**, which can lead to **deadlock**.

A deadlock occurs when a set of transactions cannot make forward progress because each of them is waiting for resources held by others in the system.

This document describes:
- the origin of cyclic dependencies in AXI interconnects
- typical deadlock scenarios
- the difference between protocol-induced and topology-induced deadlocks
- high-level strategies to prevent deadlocks


## 2. General Deadlock Principle

A deadlock arises when the following condition is met:

> A cycle exists in the resource dependency graph.

Formally:
```
Resource A waits for Resource B
Resource B waits for Resource C
...
Resource N waits for Resource A
```

In hardware interconnects, "resources" typically include:
- buffers (FIFOs)
- arbitration grants
- target ports (slaves)
- protocol ordering constraints


## 3. Deadlock in AXI Interconnect

In AXI systems:
- transactions are split across independent channels
- ordering rules and backpressure create implicit dependencies

Deadlock is not caused by routing, but by:
- **protocol-level dependencies**
- **resource allocation policies**

> AXI deadlocks are primarily caused by *when transactions are admitted*, not how they are routed.


## 4. AXI-Specific Sources of Dependency

### 4.1 Channel Coupling
- Write transactions require:
  - AW (address)
  - W (data)
  - B (response)
- Progress depends on correct sequencing across channels


### 4.2 Backpressure Propagation
- READY/VALID handshake can stall channels
- Blocking in one channel can indirectly block others


### 4.3 Outstanding Transactions
- Multiple in-flight transactions consume shared resources
- Limited buffering can create contention cycles


### 4.4 Ordering Constraints
- Same ID transactions must respect ordering rules
- Some interconnects enforce stronger ordering than required


### 4.5 Shared Target Resources
- Slaves may serialize requests
- Internal slave buffering can contribute to system-level dependencies


## 5. Canonical Deadlock Scenarios

### 5.1 Cross-Dependency Between Masters and Slaves

Two or more masters issue transactions to different slaves, then attempt cross-access:

```
M0 → S0 (holds resources)
M1 → S1 (holds resources)

M0 → S1 (blocked)
M1 → S0 (blocked)
```

If:
- S0 waits for completion of M0
- S1 waits for completion of M1
- and neither can progress

→ cyclic dependency forms.


### 5.2 AW/W Decoupling Deadlock

AXI allows AW and W channels to be independent.

Scenario:
- AW transactions are fully accepted into slave-side buffers
- W channel is stalled (e.g. arbitration or buffering limits)

Effects:
- slaves wait for W data to complete writes
- masters cannot send W because of congestion
- AW buffers remain full, blocking new transactions

→ cycle between AW buffers and W channel availability


### 5.3 Buffer Exhaustion Deadlock

Finite buffering can create global dependencies:

- all buffers in the system are occupied by partially completed transactions
- none can progress because they require additional resources

Example:
- W data cannot advance because output buffers are full
- output buffers cannot drain because responses are blocked
- responses depend on completion of stalled writes


### 5.4 Ordering-Induced Deadlock (ID Constraints)

AXI enforces ordering per ID.

Scenario:
```
Txn0 (ID=X) → S0 (blocked)
Txn1 (ID=X) → S1 (must wait for Txn0)
```

If:
- Txn0 depends (directly or indirectly) on progress of Txn1

→ hidden cyclic dependency via ordering rules


### 5.5 Response Channel Backpressure

Write response (B) or read response (R) channels can create feedback loops:

- slave cannot send response (B/R blocked)
- therefore cannot free internal resources
- therefore cannot accept new transactions
- upstream components stall


### 5.6 Starvation Leading to Effective Deadlock

Not a strict cycle initially, but:

- arbitration permanently favors some flows
- others never make progress
- system fills with blocked transactions

→ system reaches a state indistinguishable from deadlock


## 6. Key Observation

All AXI deadlock scenarios can be reduced to:

> A cyclic dependency between:
> - admission control
> - buffering
> - channel progression
> - ordering constraints


## 7. Deadlock Prevention Strategies

### 7.1 Admission Control (Core Principle)

Control when a transaction is allowed into the system.

Goal:
- avoid introducing a transaction that could complete a dependency cycle

Typical techniques:
- limit outstanding transactions per destination
- require availability of all required downstream resources before accepting


### 7.2 Channel Coupling Constraints

Enforce relationships between AW and W:
- accept AW only if W can be guaranteed to progress
- track write data availability before admitting address


### 7.3 Resource Reservation

Reserve all required resources upfront:
- buffers
- path to destination
- response capacity

Prevents partial allocation that leads to deadlock


### 7.4 Strict Ordering / Serialization

Reduce concurrency to eliminate cycles:
- per-master or per-slave serialization
- ordered transaction issue

Trade-off:
- reduced performance


### 7.5 Virtual Channels / Resource Partitioning

Separate traffic classes:
- independent buffering domains
- break cyclic dependencies

More common in NoC, but applicable to AXI buffering structures


### 7.6 Fair Arbitration

Prevent starvation:
- round-robin or age-based arbitration
- forward progress guarantees


### 7.7 Protocol-Conscious Design

Design interconnect behavior aligned with AXI semantics:
- avoid over-constraining ordering
- ensure forward progress on all channels


## 8. Design Guidelines

- Deadlock prevention must be handled at **transaction admission points**
- Avoid partial resource allocation without completion guarantees
- Always consider **cross-channel dependencies (AW/W/B, AR/R)**
- Model the system as a **resource dependency graph**
- Validate using stress scenarios with:
  - multiple masters
  - full buffering
  - worst-case ordering constraints


## 9. Summary

Deadlocks in AXI interconnects are not caused by routing, but by **protocol-level interactions and resource management policies**.

A correct design ensures:
- no cyclic dependency can be formed
- every accepted transaction is guaranteed to eventually complete

Cyclic Dependency Avoidance (CDAS) is therefore a fundamental requirement for any robust AXI interconnect implementation.

To study / keywords
- protocol-level deadlock

## Resources
- https://www.youtube.com/watch?v=2r-tLn6BPy0
- https://www.youtube.com/watch?v=zqsFDPEJy0Q
- https://www.youtube.com/watch?v=FHUstUP-6_8&t=8s
- https://developer.arm.com/documentation/ddi0475/c/functional-description/operation/cyclic-dependency-avoidance-schemes--cdas-
