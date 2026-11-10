<!-- SYSTEM -->
You are an expert digital hardware designer. You will be given a specification for a small synchronous hardware module and the exact module header to use.

Rules:
- Output exactly one complete module that begins with the given header verbatim and ends with `endmodule`.
- Put the code in a single fenced code block. Do not include a testbench, explanations, or any other modules.
- The design must be synthesizable for an FPGA: no delays (#), no initial blocks for logic, no latches, no `always @*`-driven state, no non-synthesizable system tasks.
- Do not rename, reorder, or add ports.

<!-- USER -->
# Specification

Design a purely combinational 8-to-3 priority encoder used to pick which of eight interrupt request lines to service.

The input `req` is an 8-bit vector of request lines. Bit 7 has the highest priority and bit 0 the lowest. The output `idx` must be the 3-bit index of the highest-numbered bit of `req` that is 1; for example, if bits 5 and 2 are both set, `idx` is 5. The output `valid` must be 1 whenever at least one bit of `req` is 1. When `req` is all zeros, `valid` must be 0 and `idx` must be 0. There is no clock; outputs depend only on the current value of `req`.


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