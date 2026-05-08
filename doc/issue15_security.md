# Security Policy

## 1. Overview

This feature implements a lightweight access control mechanism using:

- Full exploitation of AXI `APROT[2:0]` attributes
- A static, non-forgeable `TRUSTED` attribute per master port
- A static, non-forgeable `ENFORCE` vector attribute per master port (optional)
- A static, non-forgeable `RESTRICTED` attribute per slave port (optional)
- A static, non-forgeable `PROTECTION` vector attribute per slave port

It enforces transaction consistency with system policy, without introducing full master identity
tracking or a dedicated firewall. It complements the routing setup by ensuring the transactions
match a certain level of security to not compromise a resource and the global system.


## 2. Master Configuration

AXI provides access permissions signals that can be used to protect against illegal transactions:

- `APROT[0]` = Privilege (1 = privileged, 0 = unprivileged)
- `APROT[1]` = Security level (1 = secure, 0 = non-secure)
- `APROT[2]` = Access type (1 = instruction, 0 = data)

These bits are treated as orthogonal attributes.

In the crossbar fabric, each AXI master port is statically configured with a `TRUSTED` attribute.

`TRUSTED` : 1 bit

- `1` → trusted master (e.g., main CPU core, secured bootloader, TEE, ...)
- `0` → untrusted master (e.g., DMA, NPU, external IP)

This signal is not derived from AXI and cannot be forged.

When `TRUSTED` = 0:

- Cannot access regions marked as `RESTRICTED`
- `APROT` is treated as unverified intent

Example:
DMA claiming privileged + secure access → denied if region requires `TRUSTED`

This ensures that untrusted masters cannot escalate privileges through an `APROT` exploit.

In addition to region-based access control, a master may detect and optionally restrict accesses
where the transaction attributes represent a downgrade compared to its current state with `ENFORCE`.

Possibly:
- privileged access targeting non-privileged memory
- secure access targeting non-secure memory
- instruction fetch targeting non-executable memory

Such situations are not necessarily forbidden from a system perspective, but may indicate software
bugs, misconfigurations, or unintended behavior.

Blocking instruction fetches to non-executable regions is strongly recommended. Other downgrade
cases should typically be monitored rather than systematically prevented, unless stricter security
policies are required.

`ENFORCE` explicitly indicates the `APROT` attributes a slave must support. It follows its semantic.

## 3. Slave Configuration

Each address region is defined by:

- `START_ADDR` (`AXI_ADDR_W` bits)
- `END_ADDR` (`AXI_ADDR_W` bits)
- `PROTECTION` (3 bits)
- `RESTRICTED` (1 bit)

`PROTECTION` explicitly indicates the minimum `APROT` attributes a master should flag. It
follows its semantic.

`RESTRICTED` explicitly indicates that access to the region requires a `TRUSTED` master.


## 4. Access Evaluation

To evaluate if a transaction can be routed to a slave, each master access is evaluated with:

Address match:
`START_ADDR` <= addr <= `END_ADDR`

Slave `PROTECTION` policy:
(`APROT` & `PROTECTION`) == `PROTECTION`

Master `ENFORCE` policy:
(`ENFORCE` & `PROTECTION`) == `ENFORCE`

Trusted check:
(!`RESTRICTED`) OR (`TRUSTED`)

Final decision: all above evaluations must be positive, else access is denied. If the access is
denied, the master receives a `DECERR` on the corresponding response channel.


## 5. Policies


| PROTECTION | RESTRICTED | MEANING                   | TYPICAL USAGE |
|------------|------------|---------------------------|---------------|
| `000`      | No         | No restriction            | Open memory region. Used for debug buffers, shared RAM, or scratch space where no access control is required. Must not contain sensitive data. |
| `000`      | Yes        | No restriction            | Trusted-only shared region. Used when filtering is based solely on master identity (e.g., internal CPU communication buffers, debug mailbox restricted to trusted cores). |
| `001`      | No         | Privileged                | Kernel-accessible memory in non-secure world. Typical OS kernel data structures or control registers accessible to any master able to assert privileged APROT. Weak protection if masters are not trusted. |
| `001`      | Yes        | Privileged                | Trusted privileged region. Used for critical kernel structures, system control registers, or hypervisor-managed memory. Prevents DMA or accelerators from accessing privileged state. |
| `010`      | No         | Secure                    | Secure-tagged shared memory. Used for communication between secure-capable masters. Relies only on APROT → should not store highly sensitive assets unless all masters are trusted. |
| `010`      | Yes        | Secure                    | Trusted secure storage. Suitable for cryptographic material, secure services state, or TEE shared memory. Enforces both secure attribute and trusted origin. |
| `011`      | No         | Privileged + Secure       | Weak secure kernel region. Used in systems where all masters are implicitly trusted. Not recommended in heterogeneous SoCs due to APROT spoofing risk. ⚠️ |
| `011`      | Yes        | Privileged + Secure       | Strong secure kernel region. Typical TEE kernel memory, secure monitor, or root-of-trust firmware. Only accessible by trusted, privileged, secure masters. ✅ |
| `100`      | No         | Instruction / Data filter | Code vs data separation without trust enforcement. Used to prevent accidental execution from data regions or writes to code regions in loosely controlled systems. |
| `100`      | Yes        | Instruction / Data filter | Trusted execution/data separation. Used for executable regions (ROM, boot code) or data regions where execution must be prevented and only trusted masters can fetch instructions. |
| `101`      | No         | Privileged + Instruction  | Privileged code region. OS kernel text section in systems without strong trust separation. Vulnerable if untrusted masters can forge APROT. ⚠️ |
| `101`      | Yes        | Privileged + Instruction  | Trusted privileged code. Kernel/firmware executable region protected against DMA or external masters. Ensures only CPU-like trusted agents execute code. ✅ |
| `110`      | No         | Secure + Instruction      | Secure code (APROT-only). Used in simple systems with no adversarial masters. Not sufficient for real security guarantees. ⚠️ |
| `110`      | Yes        | Secure + Instruction      | Trusted secure execution. TEE code region, secure boot stages, or cryptographic firmware. Requires both secure attribute and trusted master. ✅ |
| `111`      | No         | Full constraint           | Fully constrained via APROT only. Rare in practice. Can be used for strict debugging or validation scenarios but not robust against malicious masters. ⚠️ |
| `111`      | Yes        | Full constraint           | Maximum security region. Root-of-trust assets, key storage, or critical firmware requiring strictest enforcement (trusted + privileged + secure + instruction). ✅ |
