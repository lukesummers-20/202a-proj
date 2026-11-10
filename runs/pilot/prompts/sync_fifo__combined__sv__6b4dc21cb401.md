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

Design a synchronous first-in-first-out buffer that stores up to 4 items of 8 bits each. The module uses a single clock `clk` and an active-low synchronous reset `rst_n`. After reset the FIFO is empty: `empty` is 1, `full` is 0, and `rd_data` is 0.

On each rising edge of `clk`, a write is accepted if `wr_en` is 1 and the FIFO is not full; the accepted item `wr_data` is stored. A read is accepted if `rd_en` is 1 and the FIFO is not empty; the oldest stored item is removed and appears on `rd_data` after that clock edge, where it stays until the next accepted read. A write requested while full, or a read requested while empty, is ignored and has no effect, even if the other operation is accepted in the same cycle. A read and a write may be accepted in the same cycle, in which case the number of stored items does not change. The flags `full` and `empty` are registered and reflect the number of stored items after each clock edge: `full` is 1 exactly when 4 items are stored and `empty` is 1 exactly when 0 items are stored.


## Table description

Design the module described by the following tables. All updates happen on the rising edge of `clk`; `n` is the number of stored items (0..4), `n'` the number after the edge.

**Interface**

| Signal | Dir | Width | Description |
|---|---|---|---|
| clk | in | 1 | clock |
| rst_n | in | 1 | synchronous reset, active low: n' = 0, rd_data' = 0, empty' = 1, full' = 0 |
| wr_en | in | 1 | write request |
| wr_data | in | 8 | item to write |
| rd_en | in | 1 | read request |
| rd_data | out | 8 | registered: item removed by the most recent accepted read |
| full | out | 1 | registered: 1 iff n = 4 |
| empty | out | 1 | registered: 1 iff n = 0 |

**Operation table (rst_n = 1)**

| wr_en | rd_en | full | empty | Write accepted | Read accepted | n' | rd_data' |
|---|---|---|---|---|---|---|---|
| 0 | 0 | x | x | no | no | n | unchanged |
| 1 | 0 | 0 | x | yes | no | n + 1 | unchanged |
| 1 | 0 | 1 | x | no (ignored) | no | n | unchanged |
| 0 | 1 | x | 0 | no | yes | n − 1 | oldest item |
| 0 | 1 | x | 1 | no | no (ignored) | n | unchanged |
| 1 | 1 | 0 | 0 | yes | yes | n | oldest item |
| 1 | 1 | 1 | 0 | no (ignored) | yes | n − 1 | oldest item |
| 1 | 1 | 0 | 1 | yes | no (ignored) | n + 1 | unchanged |

**Capacity and ordering**

| Parameter | Value |
|---|---|
| Depth | 4 items |
| Width | 8 bits |
| Order | first in, first out |
| full' | 1 iff n' = 4 |
| empty' | 1 iff n' = 0 |


## Wave description

Design the module whose behavior is shown by the following timing diagrams (WaveDrom notation). Everything is synchronous to the rising edge of `clk`; each column is one `clk` cycle, inputs are sampled at the rising edge that ends the column, and outputs change just after that edge.

**Diagram 1 — fill to full, a write while full is ignored, then drain; a read while empty is ignored**

```wavedrom
{ "signal": [
  { "name": "clk",     "wave": "p............" },
  { "name": "rst_n",   "wave": "01..........." },
  { "name": "wr_en",   "wave": "0.1....0....." },
  { "name": "wr_data", "wave": "x.=====x.....", "data": ["A","B","C","D","E"] },
  { "name": "rd_en",   "wave": "0......1....0" },
  {},
  { "name": "rd_data", "wave": "=.......====.", "data": ["00","A","B","C","D"] },
  { "name": "empty",   "wave": "1..0.......1." },
  { "name": "full",    "wave": "0.....1.0...." }
],
  "head": { "text": "item E is ignored (full); reads return A,B,C,D in order; the 5th read is ignored (empty) and rd_data holds D" }
}
```

**Diagram 2 — simultaneous read and write keeps the count; read while empty is ignored**

```wavedrom
{ "signal": [
  { "name": "clk",     "wave": "p........" },
  { "name": "rst_n",   "wave": "01......." },
  { "name": "wr_en",   "wave": "0.1010..." },
  { "name": "wr_data", "wave": "x.=x=x...", "data": ["P","Q"] },
  { "name": "rd_en",   "wave": "0.101010." },
  {},
  { "name": "rd_data", "wave": "=....=.=.", "data": ["00","P","Q"] },
  { "name": "empty",   "wave": "1..0...1." },
  { "name": "full",    "wave": "0........" }
],
  "head": { "text": "cycle 2: read ignored (empty), write P accepted; cycle 4: write Q and read P in the same cycle, count stays 1; cycle 6: read Q" }
}
```

**Diagram 3 — read and write requested together while full: the read is accepted, the write is ignored**

```wavedrom
{ "signal": [
  { "name": "clk",     "wave": "p.........." },
  { "name": "rst_n",   "wave": "01........." },
  { "name": "wr_en",   "wave": "0.1....0..." },
  { "name": "wr_data", "wave": "x.=====x...", "data": ["W","X","Y","Z","V"] },
  { "name": "rd_en",   "wave": "0.....1...0" },
  {},
  { "name": "rd_data", "wave": "=......====", "data": ["00","W","X","Y","Z"] },
  { "name": "empty",   "wave": "1..0......1" },
  { "name": "full",    "wave": "0.....10..." }
],
  "head": { "text": "cycle 6: full, so item V is ignored while W is read; the FIFO then drains X,Y,Z and is empty (V was never stored)" }
}
```


# Language requirements

Write the module in synthesizable SystemVerilog: use `logic` for all internal signals, `always_ff @(posedge clk)` for sequential logic, `always_comb` for combinational logic, and `typedef enum logic [...]` for any state machine states. Use `typedef struct packed` where a grouped record is natural. Do not use `reg`, `wire` (except where a net is required), `always @*`, or integer-coded states.

# Module header (use verbatim)

```systemverilog
module sync_fifo (
    input  logic       clk,      // clock
    input  logic       rst_n,    // active-low synchronous reset
    input  logic       wr_en,    // write request
    input  logic [7:0] wr_data,  // data to write
    input  logic       rd_en,    // read request
    output logic [7:0] rd_data,  // data of the most recent accepted read (registered)
    output logic       full,     // 1 when 4 items are stored
    output logic       empty     // 1 when 0 items are stored
);
```

Write the complete module now.