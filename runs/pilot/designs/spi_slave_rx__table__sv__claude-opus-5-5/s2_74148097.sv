module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Grouped record of the three SPI inputs for synchronization
    typedef struct packed {
        logic sclk;
        logic mosi;
        logic cs_n;
    } spi_sig_t;

    spi_sig_t   sync1, sync2;     // 2-stage synchronizer
    logic       sclk_prev;        // for rising-edge detection
    logic       sclk_rise;

    logic [6:0] shift_reg;
    logic [2:0] bit_count;

    // ------------------------------------------------------------------
    // Synchronizers (reset to idle bus values)
    // ------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sync1     <= '{sclk: 1'b0, mosi: 1'b0, cs_n: 1'b1};
            sync2     <= '{sclk: 1'b0, mosi: 1'b0, cs_n: 1'b1};
            sclk_prev <= 1'b0;
        end else begin
            sync1     <= '{sclk: sclk, mosi: mosi, cs_n: cs_n};
            sync2     <= sync1;
            sclk_prev <= sync2.sclk;
        end
    end

    always_comb begin
        sclk_rise = sync2.sclk & ~sclk_prev;
    end

    // ------------------------------------------------------------------
    // Receive logic
    // ------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin                                   // E0
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else if (sync2.cs_n) begin                      // E1
            bit_count <= 3'd0;
            valid     <= 1'b0;
        end else if (sclk_rise) begin
            if (bit_count == 3'd7) begin                    // E3
                data      <= {shift_reg, sync2.mosi};
                valid     <= 1'b1;
                bit_count <= 3'd0;
            end else begin                                  // E2
                shift_reg <= {shift_reg[5:0], sync2.mosi};
                bit_count <= bit_count + 3'd1;
                valid     <= 1'b0;
            end
        end else begin                                      // E4
            valid <= 1'b0;
        end
    end

endmodule
