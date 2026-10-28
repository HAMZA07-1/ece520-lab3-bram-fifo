\# ECE 520/L Lab 3: Single-Clock BRAM FIFO



\## Overview



In this lab, I implemented a single-clock FIFO in VHDL for the Zybo Z7-10 FPGA. A FIFO stores words and returns them in the order they were written: first in, first out.



The design uses a 32-word by 16-bit memory, read and write pointers, an occupancy counter, status flags, and a synchronous read output. A Python script generates simulation input data, and a self-checking VHDL testbench verifies the FIFO's behavior.



\## Design Summary



| Setting | Value |

|---|---:|

| Data width | 16 bits |

| FIFO depth | 32 words |

| Almost-full threshold | 31 words |

| Almost-empty threshold | 1 word |

| Read latency used for this run | 1 clock |

| Reset | Synchronous, active high |

| Zybo Z7-10 FPGA part | `xc7z010clg400-1` |



The write pointer selects the memory location for the next accepted write. The read pointer selects the oldest stored word. Both pointers wrap back to address 0 after reaching the end of the 32-word memory. The occupancy counter tracks 0 through 32 words, so `DATA\_COUNT` is 6 bits wide.



A write request is ignored when the FIFO is full. A read request is ignored when it is empty. `FULL`, `EMPTY`, `ALMOST\_FULL`, and `ALMOST\_EMPTY` report the FIFO's status.



\## Repository Contents



```text

src/sc\_fifo.vhd

sim/tb\_sc\_fifo.vhd

sim/input\_data.txt

scripts/generate\_fifo\_data.py

scripts/create\_project.tcl

reports/synthesis.log

reports/resource\_utilization\_synth.rpt

reports/timing\_summary\_synth.rpt

