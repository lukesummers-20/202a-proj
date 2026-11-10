<!-- SYSTEM -->
You are an expert digital hardware designer. You will be given a specification for a small synchronous hardware module and the exact module header to use.

Rules:
- Output exactly one complete module that begins with the given header verbatim and ends with `endmodule`.
- Put the code in a single fenced code block. Do not include a testbench, explanations, or any other modules.
- The design must be synthesizable for an FPGA: no delays (#), no initial blocks for logic, no latches, no `always @*`-driven state, no non-synthesizable system tasks.
- Do not rename, reorder, or add ports.

<!-- USER -->
# Specification

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

Write the module in synthesizable SystemVerilog: use `logic` for all internal signals, `always_ff @(posedge clk)` for sequential logic, `always_comb` for combinational logic, and `typedef enum logic [...]` for any state machine states. Use `typedef struct packed` where a grouped record is natural. Do not use `reg`, `wire` (except where a net is required), `always @*`, or integer-coded states.

# Module header (use verbatim)

```systemverilog
module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);
```

Write the complete module now.