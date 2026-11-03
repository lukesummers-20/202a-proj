<!-- SYSTEM -->
You are an expert digital hardware designer. You will be given a specification for a small synchronous hardware module and the exact module header to use.

Rules:
- Output exactly one complete module that begins with the given header verbatim and ends with `endmodule`.
- Put the code in a single fenced code block. Do not include a testbench, explanations, or any other modules.
- The design must be synthesizable for an FPGA: no delays (#), no initial blocks for logic, no latches, no `always @*`-driven state, no non-synthesizable system tasks.
- Do not rename, reorder, or add ports.

<!-- USER -->
# Specification

Design an SPI slave receiver that captures one byte at a time from an SPI master operating in mode 0 (CPOL = 0, CPHA = 0).

The module is clocked by the system clock `clk` and has an active-low synchronous reset `rst_n`. The SPI signals `sclk`, `mosi`, and `cs_n` come from the master and are asynchronous to `clk`; the system clock is guaranteed to run at least 8 times faster than `sclk`, so the SPI inputs must be synchronized into the `clk` domain and SPI clock edges detected in that domain rather than using `sclk` as a clock.

A transfer begins when `cs_n` goes low. While `cs_n` is low, the master drives one data bit per `sclk` period, most significant bit first, and the slave must sample `mosi` on each rising edge of `sclk`. After the eighth bit has been sampled, the received byte must appear on `data` and `valid` must be asserted high for exactly one `clk` cycle; `data` must then hold its value until the next byte completes. If the master keeps `cs_n` low, subsequent groups of eight `sclk` pulses deliver subsequent bytes in the same way. Whenever `cs_n` is high the receiver is idle and its bit count is cleared, so the first `sclk` rising edge after `cs_n` falls is always bit 7 of a new byte.

`valid` may be asserted up to 6 `clk` cycles after the eighth `sclk` rising edge, to allow for synchronization and edge-detection latency. After reset, `data` is 0 and `valid` is 0.


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