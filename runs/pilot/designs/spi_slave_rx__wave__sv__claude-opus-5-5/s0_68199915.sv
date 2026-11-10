module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Grouped record of the three SPI input signals
    typedef struct packed {
        logic sclk;
        logic mosi;
        logic cs_n;
    } spi_t;

    // Two-stage synchronizer, plus an extra sclk stage for edge detection
    spi_t sync1, sync2;
    logic sclk_d;

    logic       sclk_rise;
    logic [6:0] shreg;
    logic [2:0] bitcnt;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sync1  <= '{sclk: 1'b0, mosi: 1'b0, cs_n: 1'b1};
            sync2  <= '{sclk: 1'b0, mosi: 1'b0, cs_n: 1'b1};
            sclk_d <= 1'b0;
        end else begin
            sync1  <= '{sclk: sclk, mosi: mosi, cs_n: cs_n};
            sync2  <= sync1;
            sclk_d <= sync2.sclk;
        end
    end

    // Rising edge of the synchronized sclk
    always_comb begin
        sclk_rise = sync2.sclk & ~sclk_d;
    end

    // Shift register, bit counter, and output registers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            shreg  <= '0;
            bitcnt <= '0;
            data   <= 8'h00;
            valid  <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (sync2.cs_n) begin
                // Deselected: discard any partial byte, re-align boundary
                bitcnt <= '0;
            end else if (sclk_rise) begin
                if (bitcnt == 3'd7) begin
                    // 8th bit received: publish the completed byte
                    data   <= {shreg, sync2.mosi};
                    valid  <= 1'b1;
                    bitcnt <= '0;
                end else begin
                    shreg  <= {shreg[5:0], sync2.mosi};
                    bitcnt <= bitcnt + 3'd1;
                end
            end
        end
    end

endmodule
