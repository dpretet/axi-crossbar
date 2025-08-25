# Synthesis

This folder contains basic synthesis scripts using Yosys.

To run them:

```bash

# To run AXI4 crossbar
./syn_asic.sh axicb_axi4.ys

# To run AXI4-lite crossbar
./syn_asic.sh axicb_axi4lite.ys
```
# cmos.lib

The library is a generic, very minimalist, liberty file.

AXI4 Crossbar:

| Name     |     Count  |   NAND2 Count |
| -------- | ---------- | ------------- |
| DFF      |    10656   |  106560       |
| DFFSR    |     2928   |  46848        |
| NAND     |    67013   |  67013        |
| NOR      |    23796   |  71388        |
| NOT      |     9831   |  9831         |
| Total    |   228448   |  301640       |

The gate count is extracted from Yosys synthesis and the
NAND2 is an estimation based on the next figures:

- DFF: 10 NAND2
- DFFSR: 16 NAND2
- NOR: 3 NAND2
- NOT: 1 NAND2
- NAND: 1 NAND2
