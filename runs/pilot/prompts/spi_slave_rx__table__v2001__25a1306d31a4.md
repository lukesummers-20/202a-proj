<!-- SYSTEM -->
You are an expert digital hardware designer. You will be given a specification for a small synchronous hardware module and the exact module header to use.

Rules:
- Output exactly one complete module that begins with the given header verbatim and ends with `endmodule`.
- Put the code in a single fenced code block. Do not include a testbench, explanations, or any other modules.
- The design must be synthesizable for an FPGA: no delays (#), no initial blocks for logic, no latches, no `always @*`-driven state, no non-synthesizable system tasks.
- Do not rename, reorder, or add ports.

<!-- USER -->
# Specification

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