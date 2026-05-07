# Security Policy

## 1. Overview

This feature implements a lightweight access control mechanism using:

- Full exploitation of AXI `APROT[2:0]` attributes
- A static, non-forgeable `TRUSTED` signal per master port
- A static, non-forgeable `RESTRICTED` signal per slave port
- A static, non-forgeable `PROTECTION` vector signal per slave port

It enforces transaction consistency with system policy, without introducing full master identity
tracking or a dedicated firewall. It complements the routing setup by ensuring the transactions
match a certain level of security to not compromise a resource and the global system.


## 2. Master Configuration

AXI provides access permissions signals that can be used to protect against illegal transactions:

- `APROT[0]` = Privilege (1 = privileged, 0 = unprivileged)
- `APROT[1]` = Security level (1 = secure, 0 = non-secure)
- `APROT[2]` = Access type (1 = instruction, 0 = data)

These bits are treated as orthogonal attributes.

In the crossbar fabric, each AXI master port is statically configured with a `TRUSTED` label.

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

APROT match:
(`APROT` & `PROTECTION`) == `PROTECTION`

Trusted check:
(!`RESTRICTED`) OR (`TRUSTED`)

Final decision: all above evaluations must be positive, else access is denied. If the access is
denied, the master receives a `DECERR` on the response channel.


## 5. Policies


| PROTECTION | RESTRICTED | MEANING                   | TYPICAL USAGE |
|------------|------------|---------------------------|---------------|
| `000`      | No         | No restriction            | Open memory / debug |
| `000`      | Yes        | No restriction            | Trusted-only shared region |
| `001`      | No         | Privileged                | Kernel (non-secure) |
| `001`      | Yes        | Privileged                | Trusted kernel space |
| `010`      | No         | Secure                    | Secure shared buffer |
| `010`      | Yes        | Secure                    | Trusted secure region |
| `011`      | No         | Privileged + Secure       | Weak secure policy (APROT-only) ⚠️ |
| `011`      | Yes        | Privileged + Secure       | Strong secure CPU region ✅ |
| `100`      | No         | Instruction / Data filter | Code/Data separation |
| `100`      | Yes        | Instruction / Data filter | Trusted execution/data |
| `101`      | No         | Privileged + Instruction  | Privileged code |
| `101`      | Yes        | Privileged + Instruction  | Trusted privileged code ✅ |
| `110`      | No         | Secure + Instruction      | Secure code (weak) ⚠️ |
| `110`      | Yes        | Secure + Instruction      | Trusted secure execution ✅ |
| `111`      | No         | Full constraint           | Over-constrained (rare) ⚠️ |
| `111`      | Yes        | Full constraint           | Fully trusted execution ✅ |
