<!-- SYSTEM -->
You are an expert digital hardware designer. You will be given a specification for a small synchronous hardware module and the exact module header to use.

Rules:
- Output exactly one complete module that begins with the given header verbatim and ends with `endmodule`.
- Put the code in a single fenced code block. Do not include a testbench, explanations, or any other modules.
- The design must be synthesizable for an FPGA: no delays (#), no initial blocks for logic, no latches, no `always @*`-driven state, no non-synthesizable system tasks.
- Do not rename, reorder, or add ports.

<!-- USER -->
# Specification

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


# Language requirements

Write the module in Verilog-2001: use `wire`/`reg`, `always @(posedge clk)` for sequential logic and `always @(*)` for combinational logic, and plain parameters/localparams for constants. Do not use SystemVerilog-only constructs (`logic`, `always_ff`, `always_comb`, `enum`, `typedef`, `struct`, interfaces).

# Module header (use verbatim)

```verilog
module sync_fifo (
    input  wire       clk,      // clock
    input  wire       rst_n,    // active-low synchronous reset
    input  wire       wr_en,    // write request
    input  wire [7:0] wr_data,  // data to write
    input  wire       rd_en,    // read request
    output reg  [7:0] rd_data,  // data of the most recent accepted read (registered)
    output reg        full,     // 1 when 4 items are stored
    output reg        empty     // 1 when 0 items are stored
);
```

Write the complete module now.