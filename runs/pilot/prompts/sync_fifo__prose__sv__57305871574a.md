<!-- SYSTEM -->
You are an expert digital hardware designer. You will be given a specification for a small synchronous hardware module and the exact module header to use.

Rules:
- Output exactly one complete module that begins with the given header verbatim and ends with `endmodule`.
- Put the code in a single fenced code block. Do not include a testbench, explanations, or any other modules.
- The design must be synthesizable for an FPGA: no delays (#), no initial blocks for logic, no latches, no `always @*`-driven state, no non-synthesizable system tasks.
- Do not rename, reorder, or add ports.

<!-- USER -->
# Specification

Design a synchronous first-in-first-out buffer that stores up to 4 items of 8 bits each. The module uses a single clock `clk` and an active-low synchronous reset `rst_n`. After reset the FIFO is empty: `empty` is 1, `full` is 0, and `rd_data` is 0.

On each rising edge of `clk`, a write is accepted if `wr_en` is 1 and the FIFO is not full; the accepted item `wr_data` is stored. A read is accepted if `rd_en` is 1 and the FIFO is not empty; the oldest stored item is removed and appears on `rd_data` after that clock edge, where it stays until the next accepted read. A write requested while full, or a read requested while empty, is ignored and has no effect, even if the other operation is accepted in the same cycle. A read and a write may be accepted in the same cycle, in which case the number of stored items does not change. The flags `full` and `empty` are registered and reflect the number of stored items after each clock edge: `full` is 1 exactly when 4 items are stored and `empty` is 1 exactly when 0 items are stored.


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