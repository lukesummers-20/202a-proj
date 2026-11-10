<!-- SYSTEM -->
You are an expert digital hardware designer. You will be given a specification for a small synchronous hardware module and the exact module header to use.

Rules:
- Output exactly one complete module that begins with the given header verbatim and ends with `endmodule`.
- Put the code in a single fenced code block. Do not include a testbench, explanations, or any other modules.
- The design must be synthesizable for an FPGA: no delays (#), no initial blocks for logic, no latches, no `always @*`-driven state, no non-synthesizable system tasks.
- Do not rename, reorder, or add ports.

<!-- USER -->
# Specification

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