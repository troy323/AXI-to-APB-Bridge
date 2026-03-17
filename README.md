# AXI-to-APB-Bridge
A synthesizable, Verilog-2001 AXI4 to APB3 bridge featuring asynchronous FWFT FIFOs for robust Clock Domain Crossing (CDC) and full AXI burst support.
# AXI4 to APB3 Bridge with Asynchronous CDC

A lightweight, fully synthesizable Verilog-2001 implementation of an AXI4 to APB3 Bridge. It is explicitly designed to interface high-performance, high-frequency AXI4 master devices (such as microprocessors or DMA controllers) with lower-frequency, low-bandwidth APB3 peripheral devices (such as UARTs, timers, or configuration registers). 

To ensure safe data transfer between independent clock networks, the bridge architecture is decoupled using custom **First-Word Fall-Through (FWFT) Asynchronous FIFOs**, making it a drop-in solution for System-on-Chip (SoC) designs requiring Clock Domain Crossing (CDC).

## Architectural Highlights

* **Robust Clock Domain Crossing (CDC):** The design is split into two distinct state machines: the AXI Frontend and the APB Master. They communicate exclusively through parameterized asynchronous FIFOs using Gray-code pointer synchronization. This allows the AXI bus and APB bus to run at completely independent, asynchronous frequencies without metastability issues.
* **Automated Burst Translation:** Standard APB3 does not support bursts. This bridge features an internal address calculation engine that automatically unrolls AXI4 `INCR`, `WRAP`, and `FIXED` bursts. A single multi-beat AXI transaction is seamlessly translated into a sequence of individual, byte-addressed APB transfers.
* **Lightweight & Strictly In-Order (No IDs):** By stripping out AXI ID tracking (`AWID`, `ARID`, etc.), this bridge minimizes logic utilization and routing congestion. It enforces strict, in-order execution of transactions, which is ideal for endpoint memory-mapped register configuration.
* **Full Byte Addressing:** Natively handles standard 32-bit (4-byte) AXI/APB boundaries, passing unshifted byte addresses (`0x0`, `0x4`, `0x8`) directly to the APB bus to maintain software compatibility with standard memory maps.

## Internal Data Flow

1. **Write Path:** The AXI Frontend accepts Address (`AW`) and Data (`W`) channels. It calculates the necessary burst addresses and pushes an encapsulated packet `{Write_Flag, Last_Flag, Address, Data}` into the **Request FIFO**. The APB Master pops this data, executes the `PENABLE`/`PSEL` setup and access phases, and pushes a response back.
2. **Read Path:** The AXI Frontend accepts the Address (`AR`) channel, calculates the burst beats, and pushes dummy data with a Read Flag to the **Request FIFO**. The APB Master executes the reads on the peripheral bus and pushes the returned `PRDATA` into the **Response FIFO**. The AXI Frontend pops this data and drives the AXI `R` channel back to the master.

## Directory Structure

```text
├── rtl/
│   └── axi2apb_2fifo_simple_noid.v   # Top-level bridge wrapper and sub-modules
├── tb/
│   └── tb_axi2apb.v                  # Self-checking testbench with CDC generation
├── README.md                         # Project documentation
└── LICENSE                           # MIT License
