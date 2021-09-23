# AXI ID Usage in the crossbar

## AMBA Specification

Follow the AMBA AXI4 specification part related to the ordering model.


### Definition of the ordering model


The AXI4 protocol supports an ordering model based on the use of the AXI ID
transaction identifier.

The principles are that for transactions with the same ID:
- Transactions to any single peripheral device, must arrive at the peripheral
  in the order in which they are issued, regardless of the addresses of the
  transactions.
- Memory transactions that use the same, or overlapping, addresses must arrive
  at the memory in the order in which they are issued.

Note:

In an AXI system with multiple masters, the AXI IDs used for the ordering model
include the infrastructure IDs, that identify each master uniquely. This means
the ordering model applies independently to each master in the system.

The AXI ordering model also requires that all transactions with the same ID in
the same direction must provide their responses in the order in which they are
issued. Read and write address channels are independent and in this
specification, are defined to be in different directions. If an ordering
relationship is required between two transactions with the same ID that are in
different directions, then a master must wait to receive a response to the
first transaction before issuing the second transaction.  If a master issues a
transaction in one direction before it has received a response to an earlier
transaction in the opposite direction, then there are no ordering guarantees
between the two transactions.

Note:

Where guaranteed ordering requires a response to an earlier transaction, a
master must ensure it has received a response from an appropriate point in the
system. A response from an intermediate AXI component cannot guarantee ordering
with respect to components that are downstream of the intermediate buffer.


### Master Ordering

A master that issues multiple read or write transactions in the same direction
with the same ID has the following guarantees about the ordering of these
transactions:

- The order of response at the master to all transactions must be the same as
  the order of issue.
- For transactions to Device memory, the order of arrival at the slave must be
  the same as the order of issue.
- For Normal memory, the order of arrival at the slave of transactions to the
  same or overlapping addresses, must be the same as the order of issue. This
  also applies to transactions to cacheable memory and all valid transactions
  for which AxCACHE[3:1] is not 0b000.


### Interconnect Ordering

To meet the requirements of the ordering model, the interconnect must ensure that:

- The order of transactions in the same direction with the same ID to Device
  memory is preserved.
- The order of transactions in the same direction with the same ID to the same
  or overlapping addresses is preserved.
- The order of write responses with the same ID is preserved.
- The order of read responses with the same ID is preserved.
- Any manipulation of the AXI ID values associated with a transaction must
  ensure that the ordering requirements of the original ID values are
  maintained.
- Any component that gives a response to a transaction before the transaction
  reaches its final destination must ensure that the ordering requirements
  given in this section are maintained until the transaction reaches its final
  destination.



### Slave Ordering


To meet the requirements of the ordering model, a slave must ensure that:

- Any write transaction for which it has issued a response must be observed by
  any subsequent write or read transaction, regardless of the transaction IDs.
- Any write transaction to Device memory must be observed by any subsequent
  write to Device memory with the same ID, even if a response has not yet been
  issued.
- Any write transaction to Normal memory must be observed by any subsequent
  write to the same or an overlapping address with the same ID, even if a
  response has not yet been given. This also applies to transactions to
  cacheable memory and applies to all valid write transactions for which
  AWCACHE[3:1] is not 0b000.
- Responses to multiple write transactions with the same ID must be issued in
  the order in which the transactions arrived.
- Responses to multiple write transactions with different IDs can be issued in
  any order.
- Any read transaction for which it has issued a response must be observed by
  any subsequent write or read transaction, regardless of the transaction IDs.
- Any read transaction to Device memory must be observed by any subsequent read
  to Device memory with the same ID, even if a response has not yet been
  issued.
- Responses to multiple read transactions with the same ID must be issued in
  the order in which the transactions arrive.
- Responses to multiple read transactions with different IDs can be issued in
  any order.



### Personal note

Master:

The behavior is obvious in the above statements from the specfication: if
requests use the same ID, the completions are served in the same order, else
they may be served out-of-order.


Interconnect:

The ordering model applies independently to each master in the system.

The interconnect must ensure the response ordering remain the same than the order
the requests have been issued. It's allowed to manipulate the IDs routed to the
slaves if the completion flow respects the original ordering.

The difficulty for an interconnect circuit is to manage the responses in case
of out-of-order completion if a master require in-order completion. However, this
scenario would be a nice-to-have feature, not mandatory and could be useful for
instance in a bridge between two protocols.

Slave:

The difficulty for a slave is to support in-order completion. For instance,
if a slave implements algorithms which not execute in the same time, the slave
would need a reodering stage to serve the completion in-order. the number of
supported outstanding requests allowed would drasticaly increase the complexity
of such stage.
