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

Write the module in Verilog-2001: use `wire`/`reg`, `always @(posedge clk)` for sequential logic and `always @(*)` for combinational logic, and plain parameters/localparams for constants. Do not use SystemVerilog-only constructs (`logic`, `always_ff`, `always_comb`, `enum`, `typedef`, `struct`, interfaces).

# Module header (use verbatim)

```verilog
module prio_enc8 (
    input  wire [7:0] req,    // interrupt request lines; bit 7 has the highest priority
    output reg  [2:0] idx,    // index of the highest-priority asserted request
    output reg        valid   // 1 when at least one request is asserted
);
```

Write the complete module now.