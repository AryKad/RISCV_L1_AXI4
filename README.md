# RISCV_L1_AXI4

> RV32I+M 5-stage pipelined processor with L1 caches and AXI4 bus interface, targeting Nexys A7 100T

A fully custom RISC-V SoC implementation in Verilog, built from scratch as a portfolio project targeting MS applications in VLSI/Microelectronics. The design implements the RV32I+M ISA with a classic 5-stage pipeline, Harvard-architecture L1 caches, and AXI4/AXI4-Lite bus interfaces for memory-mapped peripherals.

---

## Architecture Overview

```
         ┌─────────────────────────────────────────────────────┐
         │                  RISC-V Core (RV32I+M)              │
         │                                                     │
         │   ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐│
         │   │  IF  │→ │  ID  │→ │  EX  │→ │ MEM  │→ │  WB  ││
         │   └──────┘  └──────┘  └──────┘  └──────┘  └──────┘│
         │       │                               │             │
         └───────┼───────────────────────────────┼─────────────┘
                 │                               │
         ┌───────▼──────┐               ┌────────▼─────┐
         │   I-Cache    │               │   D-Cache    │
         │  4KB, 4-way  │               │  4KB, 4-way  │
         │  Set-Assoc   │               │  Set-Assoc   │
         │  pseudo-LRU  │               │  Write-Back  │
         └───────┬──────┘               └──────┬───────┘
                 │           AXI4              │
                 └──────────────┬──────────────┘
                                │
                    ┌───────────▼───────────┐
                    │      AXI4 Fabric      │
                    └───────────┬───────────┘
                                │
               ┌────────────────┴──────────────┐
               │                               │
       ┌───────▼──────┐               ┌────────▼──────┐
       │  Block RAM   │               │     UART      │
       │   (BRAM)     │               │  (AXI4-Lite)  │
       └──────────────┘               └───────────────┘
```

---

## Specifications

| Parameter | Value |
|---|---|
| ISA | RV32I + M extension |
| Pipeline | 5-stage (IF, ID, EX, MEM, WB) |
| Branch Prediction | Predict-Not-Taken |
| I-Cache | 4KB, 4-way set-associative, pseudo-LRU |
| D-Cache | 4KB, 4-way set-associative, write-back / write-allocate, pseudo-LRU |
| Cache-to-Memory Bus | AXI4 (full) |
| Peripheral Bus | AXI4-Lite |
| Peripheral | UART |
| Target FPGA | Nexys A7 100T (Artix-7 XC7A100T) |

---

## Implementation Status

| Module | Status | Simulated |
|---|---|---|
| ALU | ✅ Complete | ✅ |
| Register File | ✅ Complete | ✅ |
| IF Stage | ✅ Complete | ✅ |
| ID Stage | ✅ Complete | ✅ |
| EX Stage | ✅ Complete | ✅ |
| MEM Stage | ✅ Complete | ✅ |
| WB Stage | ✅ Complete | ✅ |
| Hazard Unit | ✅ Complete | ✅ |
| I-Cache | 🔄 In Progress | ❌ |
| D-Cache | ⏳ Pending | ❌ |
| AXI4 Master | ⏳ Pending | ❌ |
| AXI4-Lite Master | ⏳ Pending | ❌ |
| UART | ⏳ Pending | ❌ |
| Top-level Integration | ⏳ Pending | ❌ |
| FPGA Implementation | ⏳ Pending | — |

---

## Repository Structure

```
RISCV_L1_AXI4/
├── rtl/
│   ├── core/           # Pipeline stages, ALU, register file, hazard unit
│   ├── cache/          # L1 instruction and data caches
│   ├── axi4/           # AXI4 and AXI4-Lite bus masters
│   ├── uart/           # UART peripheral
│   └── riscv_core.v    # Top-level integration
├── tb/                 # Testbenches (per-module and top-level)
├── constraints/        # Vivado XDC constraints for Nexys A7 100T
├── sim/
│   └── waveforms/      # Simulation waveform dumps
├── docs/
│   ├── architecture.md # Detailed microarchitecture notes
│   └── diagrams/       # SVG architecture diagrams
├── LICENSE
└── README.md
```

---

## Pipeline Details

### Stages
- **IF** — Instruction fetch from I-Cache; PC update with predict-not-taken branch prediction
- **ID** — Instruction decode, register file read, immediate generation, hazard detection
- **EX** — ALU execution (RV32I+M), branch resolution, forwarding MUX control *(in progress)*
- **MEM** — D-Cache access, load/store alignment
- **WB** — Write-back to register file

### Hazard Handling
- **Data hazards** — Resolved via forwarding (EX/MEM → EX) with stall for load-use hazards
- **Control hazards** — Predict-not-taken; flush on branch misprediction

### M Extension
The M extension (integer multiply/divide) is implemented in the EX stage using dedicated multiplier/divider units, with stall-based multi-cycle latency handling.

---

## Cache Architecture

Both I-Cache and D-Cache share the same structural parameters:

- **Size:** 4KB
- **Associativity:** 4-way set-associative
- **Replacement Policy:** Pseudo-LRU
- **Block Size:** 32 bytes (256 bits, matching AXI4 burst width)

D-Cache additionally implements:
- **Write policy:** Write-back
- **Allocation policy:** Write-allocate
- **Dirty bit tracking** per cache line for writeback on eviction

---

## Bus Interface

- **AXI4 (full)** — Used for cache-to-BRAM data transfers; supports burst transactions for cache line fill/evict
- **AXI4-Lite** — Used for UART register-mapped I/O; single-beat read/write only

---

## Tools & Environment

| Tool | Version |
|---|---|
| Simulator | Vivado Simulator (xsim) |
| Synthesis & Implementation | Vivado 2024.x |
| Target Device | Nexys A7 100T (XC7A100T-1CSG324C) |
| HDL | Verilog (IEEE 1364-2001) |

---

## Motivation

This project is the flagship hardware design piece of my MS application portfolio, targeting programs in VLSI and Microelectronics at European universities (TU Munich, TU Dresden, RWTH Aachen, TU Delft). The design choices — pipelined Harvard architecture, cache hierarchy, AXI4 bus — were made to reflect industry-relevant microarchitecture decisions, not just RTL correctness.

---

## License

MIT — see [LICENSE](LICENSE)
