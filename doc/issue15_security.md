# Security Policy

## 1. Overview

This feature implements a lightweight access control mechanism using:

- Full exploitation of AXI `APROT[2:0]` attributes
- A static, non-forgeable `TRUSTED` signal per master port

It enforces transaction consistency with system policy, without introducing full master identity
tracking or a dedicated firewall.

---

## 2. APROT Semantics

`APROT[0]` = Privileged (1 = privileged, 0 = unprivileged)
`APROT[1]` = Secure (1 = secure, 0 = non-secure)
`APROT[2]` = Instruction (1 = instruction, 0 = data)

These bits are treated as orthogonal attributes.

---

## 3. Master Attribute

Each AXI master port is statically configured with:

`TRUSTED` : 1 bit

- `1` → trusted master (e.g., CPU)
- `0` → untrusted master (e.g., DMA, NPU, external IP)

This signal is not derived from AXI and cannot be forged.

---

## 4. Region Configuration

Each address region is defined by:

- `START_ADDR` (`AXI_ADDR_W` bits)
- `END_ADDR` (`AXI_ADDR_W` bits)
- `APROT_MASK` (3 bits)
- `SECURED` (1 bit)

---

## 5. Access Evaluation

Address match:
`START_ADDR` <= addr <= `END_ADDR`

APROT match:
(`APROT` & `APROT_MASK`) == `APROT`

Trusted check:
(!`SECURED`) OR (`TRUSTED`)

Final decision: all above evaluations must be positive, else access is denied.

---

## 6. Typical Policy Examples

Secure privileged region:
- APROT_MASK = 0b011
- aprot = 0b011
- SECURED = 1

Data-only region:
- APROT_MASK = 0b100
- aprot = 0b000
- SECURED = 0

Instruction-only region:
- APROT_MASK = 0b100
- aprot = 0b100
- SECURED = 1

Non-secure shared buffer:
- APROT_MASK = 0b010
- aprot = 0b000
- SECURED = 0

---

## 7. Handling of Untrusted Masters

When `TRUSTED` = 0:

- Cannot access regions requiring trusted
- `APROT` is treated as unverified intent

Example:
DMA claiming privileged + secure access → denied if region requires trusted

---

## 8. Inconsistent or Suspicious APROT Usage

Examples:

- Instruction access from non-CPU master
- Privileged access from untrusted master
- Secure access from unexpected master
- Inconsistent APROT usage patterns

Handling:
- Enforced via policy (strict mode)
- Or optionally logged

