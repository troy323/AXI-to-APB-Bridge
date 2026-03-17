# AXI4 to APB3 Bridge with Asynchronous CDC

![Language](https://img.shields.io/badge/Language-Verilog--2001-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Status](https://img.shields.io/badge/Status-Simulation_Verified-brightgreen.svg)

A lightweight, fully synthesizable Verilog-2001 implementation of an **AXI4 to APB3 Bridge**. It is explicitly designed to interface high-performance, high-frequency AXI4 master devices (e.g., microprocessors, DMA controllers) with lower-frequency, low-bandwidth APB3 peripheral devices (e.g., UARTs, timers, configuration registers). 

To ensure safe data transfer between independent clock networks, the architecture is decoupled using custom **First-Word Fall-Through (FWFT) Asynchronous FIFOs**, making it a drop-in solution for System-on-Chip (SoC) designs requiring Clock Domain Crossing (CDC).

---

## 🚀 Key Features

* **Robust Clock Domain Crossing (CDC):** Independent `s_axi_aclk` and `pclk` domains handled via Gray-code synchronized async FIFOs.
* **Automated Burst Translation:** Automatically unrolls AXI4 `INCR`, `WRAP`, and `FIXED` bursts. A single multi-beat AXI transaction seamlessly translates into a sequence of individual APB transfers.
* **Strictly In-Order (No IDs):** Strips out AXI ID tracking (`AWID`, `ARID`) to minimize logic utilization and routing congestion, ideal for endpoint memory-mapped register configuration.
* **Full Byte Addressing:** Natively handles standard 32-bit (4-byte) AXI/APB boundaries, passing unshifted byte addresses (`0x0`, `0x4`, `0x8`) directly to the APB bus.
* **Zero Wait-State Compatible:** Highly efficient state machines designed to communicate flawlessly with zero-wait-state APB slaves.

---

## ⚙️ Configuration Parameters

The IP is highly parameterized to fit various SoC requirements.

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `AXI_ADDR_W` | `32` | Width of the AXI4 address bus. |
| `APB_ADDR_W` | `32` | Width of the APB3 address bus (Full Byte Address). |
| `REQ_FIFO_AW` | `4` | Request FIFO address width (Depth = 2^4 = 16 entries). |
| `RSP_FIFO_AW` | `4` | Response FIFO address width (Depth = 2^4 = 16 entries). |

---

## 🏗️ Architecture & Internal Data Flow
1. **Write Path:** The AXI Frontend accepts Address (`AW`) and Data (`W`) channels. It calculates necessary burst addresses and pushes an encapsulated packet `{Write_Flag, Last_Flag, Address, Data}` into the **Request FIFO**. The APB Master pops this data, executes the `PENABLE`/`PSEL` setup and access phases, and pushes a response back.
2. **Read Path:** The AXI Frontend accepts the Address (`AR`) channel, calculates the burst beats, and pushes a dummy payload with a Read Flag to the **Request FIFO**. The APB Master executes the reads on the peripheral bus and pushes the returned `PRDATA` into the **Response FIFO**. The AXI Frontend pops this data and drives the AXI `R` channel back to the master.

---
### Simulation Output

Running the testbench yields the following clean transcript, proving successful data routing and functional correctness across the asynchronous boundary:

```text
--- Starting Single Transfer Tests ---
[APB] Wrote Data: deadbeef to Addr: 00000000
[AXI] Completed Write: Data deadbeef to Addr 00000000
[APB] Wrote Data: cafebabe to Addr: 00000004
[AXI] Completed Write: Data cafebabe to Addr 00000004
[APB] Read Data: deadbeef from Addr: 00000000
[AXI] Completed Read: Data deadbeef from Addr 00000000
[APB] Read Data: cafebabe from Addr: 00000004
[AXI] Completed Read: Data cafebabe from Addr 00000004
--- Simulation Complete ---



---

## 📂 Directory Structure

```text
├── rtl/
│   └── axi2apb_2fifo_simple_noid.v   # Top-level bridge wrapper and sub-modules
├── tb/
│   └── tb_axi2apb_waveform.v         # Self-checking testbench with CDC generation
├── README.md                         # Project documentation
└── LICENSE                           # MIT License
