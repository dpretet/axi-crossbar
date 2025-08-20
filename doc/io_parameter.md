# Inputs/Outputs & Parameters

## Parameters

- AXI_ADDR_W
    - Address width for both read and write address channels
    - Any value from 1 bit
- AXI_ID_W
    - ID width for both read and write address/completion channels
    - Any value from 1 bit
- AXI_DATA_W
    - ID width for both read and write data channels
    - Any value from 1 bit
- MST_PIPELINE
    - Enable pipeline stage on switching logic inputs from the master agents
    - 1 = add the pipeline stage, otherwise 0
- SLV_PIPELINE
    - Enable pipeline stage on switching logic output to the slave agents
    - 1 = add the pipeline stage, otherwise 0
- AXI_SIGNALING
    - Specify the protocol supported by the core. Apply to the whole topology
    - 0 = AXI4-lite, 1 = AXI4
- USER_SUPPORT
    - Enable user specific sideband signal in all AXI channels. Apply to the whole topology
    - 1 = support sideband signals, 0 = no sideband signals
- AXI_AUSER_W
    - Specify in bit the width of address sideband signals
    - Apply to both read and write address channels
    - Any value from 1 bit
- AXI_WUSER_W
    - Specify in bit the width of write data sideband signals
    - Any value from 1 bit
- AXI_BUSER_W
    - Specify in bit the width of write response sideband signals
    - Any value from 1 bit
- AXI_RUSER_W
    - Specify in bit the width of read data sideband signals
    - Apply to both read and write address channels
    - Any value from 1 bit

Follow description of parameters common to all interfaces on which
a master agent is connected:

- MSTx_CDC
    - Implement a CDC stage for master x
    - 1 = activated, 0 = no CDC
- MSTx_OSTDREQ_NUM
    - Number of outstanding request supported for master x
    - Any value from 1
- MSTx_OSTDREQ_SIZE
    - Number of dataphase of an outstanding request for master x
    - Any power of 2 value between 1 and 256
- MSTx_PRIORITY
    - Priority a master will be garanteed in a switching
    - Value between 0 (low priority) and 3 (high priority)
- MSTx_ROUTES
    - The slave agent a master can target
    - 4 bits, one per slave. Bit0 is slave0, ..., bit3 is slave3
- MSTx_ID_MASK
    - A mask applied in slave completion channel to determine which master to route back the
      BRESP/RRESP completions.
    - Any value, width equal to `AXI_ID_W`

Follow description of parameters common to all interfaces on which a 
slave agent is connected:

- SLVx_CDC
    - Implement a CDC stage for slave x
    - 1 = activated, 0 = no CDC
- SLVx_OSTDREQ_NUM
    - Number of outstanding request supported for slave x
    - Any value from 1
- SLVx_OSTDREQ_SIZE
    - Number of dataphase of an outstanding request for slave x
    - Any power of 2 value between 1 and 256
- SLVx_START_ADDR
    - Memory address from which a slave agent can be targeted
    - Any value from 0 up to 2^`AXI_ADDR_W`/8
- SLVx_END_ADDR
    - Memory address up to which a slave agent can be targeted
    - Any value from 0 up to 2^`AXI_ADDR_W`/8
- SLVx_KEEP_BASE_ADDR
    - When a reqeust is issued to a slave agent, the base address `SLVx_START_ADDR` is
      is not removed from the `AxADDR` field

## Input / Output

### AXI4 / AXI4-lite

The core complies with AXI4 and AXI4-lite signal definition. The specification of the protocol
as well the signals list can be found on 
[ARM website](https://developer.arm.com/documentation/ihi0022/latest/).

### General Interface

The following signals are the clock and reset necessary to switching logic to be functional.
Only on reset must be driven, the other one needing to be tied to `0` for srst or `1` for aresetn.
Refer to the [architecture chapter](architecture.md#clock-and-reset-network) for explanation.

- aclk
    - The clock for the switching logic and the internal buffers
    - Any frequency
- aresetn
    - Active low, asynchronous reset. Must comply to AMBA specification, asynchronous assertion,
      synchronous deassertion
- srst
    - Fully synchronous reset
