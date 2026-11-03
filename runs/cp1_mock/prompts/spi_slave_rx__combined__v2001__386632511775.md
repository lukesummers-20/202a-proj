<!-- SYSTEM -->
You are an expert digital hardware designer. You will be given a specification for a small synchronous hardware module and the exact module header to use.

Rules:
- Output exactly one complete module that begins with the given header verbatim and ends with `endmodule`.
- Put the code in a single fenced code block. Do not include a testbench, explanations, or any other modules.
- The design must be synthesizable for an FPGA: no delays (#), no initial blocks for logic, no latches, no `always @*`-driven state, no non-synthesizable system tasks.
- Do not rename, reorder, or add ports.

<!-- USER -->
# Specification

## Prose description

Design an SPI slave receiver that captures one byte at a time from an SPI master operating in mode 0 (CPOL = 0, CPHA = 0).

The module is clocked by the system clock `clk` and has an active-low synchronous reset `rst_n`. The SPI signals `sclk`, `mosi`, and `cs_n` come from the master and are asynchronous to `clk`; the system clock is guaranteed to run at least 8 times faster than `sclk`, so the SPI inputs must be synchronized into the `clk` domain and SPI clock edges detected in that domain rather than using `sclk` as a clock.

A transfer begins when `cs_n` goes low. While `cs_n` is low, the master drives one data bit per `sclk` period, most significant bit first, and the slave must sample `mosi` on each rising edge of `sclk`. After the eighth bit has been sampled, the received byte must appear on `data` and `valid` must be asserted high for exactly one `clk` cycle; `data` must then hold its value until the next byte completes. If the master keeps `cs_n` low, subsequent groups of eight `sclk` pulses deliver subsequent bytes in the same way. Whenever `cs_n` is high the receiver is idle and its bit count is cleared, so the first `sclk` rising edge after `cs_n` falls is always bit 7 of a new byte.

`valid` may be asserted up to 6 `clk` cycles after the eighth `sclk` rising edge, to allow for synchronization and edge-detection latency. After reset, `data` is 0 and `valid` is 0.


## Table description

Design the module described by the following tables.

**Interface**

| Signal | Dir | Width | Domain | Description |
|---|---|---|---|---|
| clk | in | 1 | — | system clock; all registers update on its rising edge |
| rst_n | in | 1 | clk | synchronous reset, active low; clears data, valid, and bit count |
| sclk | in | 1 | async | SPI clock from master, CPOL = 0 (idle low); f(clk) ≥ 8 × f(sclk) |
| mosi | in | 1 | async | SPI data from master, MSB first |
| cs_n | in | 1 | async | chip select, active low; a byte boundary is re-aligned every time it falls |
| data | out | 8 | clk | last complete byte; holds until the next byte completes |
| valid | out | 1 | clk | exactly one clk-cycle pulse when data is updated |

**Events (all evaluated in the clk domain after synchronizing the SPI inputs)**

| Event | Condition | Action |
|---|---|---|
| E0 | rst_n = 0 | bit_count ← 0, data ← 0, valid ← 0 |
| E1 | cs_n = 1 | bit_count ← 0 (idle); data unchanged; valid ← 0 |
| E2 | cs_n = 0 and rising edge detected on sclk and bit_count < 7 | shift_reg ← {shift_reg[6:0], mosi}; bit_count ← bit_count + 1 |
| E3 | cs_n = 0 and rising edge detected on sclk and bit_count = 7 | data ← {shift_reg[6:0], mosi}; valid ← 1 for one cycle; bit_count ← 0 |
| E4 | otherwise | valid ← 0; everything else unchanged |

**Timing requirements**

| Parameter | Value |
|---|---|
| Sampling edge of mosi | rising edge of sclk (mode 0) |
| Bit order | bit 7 first, bit 0 last |
| Latency, 8th sclk rising edge → valid | ≤ 6 clk cycles |
| valid pulse width | exactly 1 clk cycle |
| Synchronization of sclk, mosi, cs_n | required (2-stage synchronizer or equivalent) |


## Wave description

Design the module whose behavior is shown by the following timing diagrams (WaveDrom notation). `clk` is the system clock; `sclk`, `mosi`, and `cs_n` come from an SPI master and are asynchronous to `clk` (synchronize them). In Diagrams 1–3 each character column is half an `sclk` period and `clk` is not drawn: one `sclk` period is at least 8 `clk` cycles, and `valid` may rise up to 6 `clk` cycles after the 8th `sclk` rising edge.

**Diagram 1 — one byte, 0xA5, mode 0 (CPOL = 0, CPHA = 0), MSB first; mosi is sampled on sclk rising edges**

```wavedrom
{ "signal": [
  { "name": "cs_n",  "wave": "10.................1." },
  { "name": "sclk",  "wave": "0..1010101010101010.." },
  { "name": "mosi",  "wave": "x.1.0.1.0.0.1.0.1.x.." },
  { "name": "bit#",  "wave": "x.3.3.3.3.3.3.3.3.x..", "data": ["7","6","5","4","3","2","1","0"] },
  {},
  { "name": "data",  "wave": "=.................=..", "data": ["previous", "0xA5"] },
  { "name": "valid", "wave": "0.................10." }
],
  "head": { "text": "valid rises at most 6 clk cycles after the 8th sclk rising edge and lasts exactly one clk cycle; data then holds" }
}
```

**Diagram 2 — cs_n re-aligns the byte boundary (a partial byte is discarded)**

```wavedrom
{ "signal": [
  { "name": "cs_n",  "wave": "10......1.0.................1." },
  { "name": "sclk",  "wave": "0..101010...1010101010101010.." },
  { "name": "mosi",  "wave": "x.1.1.1.x..0.0.0.0.1.1.1.1.x.." },
  { "name": "note",  "wave": "x.3.....x..4.4.4.4.4.4.4.4.x..", "data": ["3 bits, no valid", "7","6","5","4","3","2","1","0"] },
  {},
  { "name": "data",  "wave": "=...........................=.", "data": ["previous", "0x0F"] },
  { "name": "valid", "wave": "0...........................10" }
]}
```

**Diagram 3 — back-to-back bytes, 0x3C then 0xC3, with cs_n held low (the 9th sclk rising edge is bit 7 of the next byte)**

```wavedrom
{ "signal": [
  { "name": "cs_n",  "wave": "10.................................1." },
  { "name": "sclk",  "wave": "0..10101010101010101010101010101010.." },
  { "name": "mosi",  "wave": "x.0.0.1.1.1.1.0.0.1.1.0.0.0.0.1.1.x.." },
  { "name": "bit#",  "wave": "x.3.3.3.3.3.3.3.3.4.4.4.4.4.4.4.4.x..", "data": ["7","6","5","4","3","2","1","0","7","6","5","4","3","2","1","0"] },
  {},
  { "name": "data",  "wave": "=.................=...............=..", "data": ["previous", "0x3C", "0xC3"] },
  { "name": "valid", "wave": "0.................10..............10." }
],
  "head": { "text": "one valid pulse per byte; data holds 0x3C until the second byte completes" }
}
```

**Diagram 4 — reset (here each column is one `clk` cycle)**

```wavedrom
{ "signal": [
  { "name": "clk",   "wave": "p......" },
  { "name": "rst_n", "wave": "1.0.1.." },
  { "name": "data",  "wave": "=..=...", "data": ["0x3C", "0x00"] },
  { "name": "valid", "wave": "0......" }
],
  "head": { "text": "rst_n is sampled on the rising edge of clk (synchronous)" }
}
```


# Language requirements

Write the module in Verilog-2001: use `wire`/`reg`, `always @(posedge clk)` for sequential logic and `always @(*)` for combinational logic, and plain parameters/localparams for constants. Do not use SystemVerilog-only constructs (`logic`, `always_ff`, `always_comb`, `enum`, `typedef`, `struct`, interfaces).

# Module header (use verbatim)

```verilog
module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);
```

Write the complete module now.