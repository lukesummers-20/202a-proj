<!-- SYSTEM -->
You are an expert digital hardware designer. You will be given a specification for a small synchronous hardware module and the exact module header to use.

Rules:
- Output exactly one complete module that begins with the given header verbatim and ends with `endmodule`.
- Put the code in a single fenced code block. Do not include a testbench, explanations, or any other modules.
- The design must be synthesizable for an FPGA: no delays (#), no initial blocks for logic, no latches, no `always @*`-driven state, no non-synthesizable system tasks.
- Do not rename, reorder, or add ports.

<!-- USER -->
# Specification

Design the purely combinational module described by the following truth table (`x` = don't care).

| req[7] | req[6] | req[5] | req[4] | req[3] | req[2] | req[1] | req[0] | idx | valid |
|---|---|---|---|---|---|---|---|---|---|
| 1 | x | x | x | x | x | x | x | 7 | 1 |
| 0 | 1 | x | x | x | x | x | x | 6 | 1 |
| 0 | 0 | 1 | x | x | x | x | x | 5 | 1 |
| 0 | 0 | 0 | 1 | x | x | x | x | 4 | 1 |
| 0 | 0 | 0 | 0 | 1 | x | x | x | 3 | 1 |
| 0 | 0 | 0 | 0 | 0 | 1 | x | x | 2 | 1 |
| 0 | 0 | 0 | 0 | 0 | 0 | 1 | x | 1 | 1 |
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 1 |
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

There is no clock; `idx` and `valid` are functions of `req` only.


# Language requirements

Write the module in synthesizable SystemVerilog: use `logic` for all internal signals, `always_ff @(posedge clk)` for sequential logic, `always_comb` for combinational logic, and `typedef enum logic [...]` for any state machine states. Use `typedef struct packed` where a grouped record is natural. Do not use `reg`, `wire` (except where a net is required), `always @*`, or integer-coded states.

# Module header (use verbatim)

```systemverilog
module prio_enc8 (
    input  logic [7:0] req,    // interrupt request lines; bit 7 has the highest priority
    output logic [2:0] idx,    // index of the highest-priority asserted request
    output logic       valid   // 1 when at least one request is asserted
);
```

Write the complete module now.