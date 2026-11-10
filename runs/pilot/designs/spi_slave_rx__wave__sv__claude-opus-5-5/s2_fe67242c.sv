module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Grouped synchronizer record for the SPI inputs
    typedef struct packed {
        logic sclk;
        logic mosi;
        logic cs_n;
    } spi_bus_t;

    spi_bus_t   sync1, sync2;
    logic       sclk_d;      // delayed synchronized sclk for edge detect
    logic       sclk_rise;
    logic [2:0] bit_cnt;
    logic [6:0] shift;

    // Two-flop synchronizers plus edge-detect history
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

    always_comb begin
        sclk_rise = sync2.sclk & ~sclk_d;
    end

    // Receive logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_cnt <= 3'd0;
            shift   <= 7'd0;
            data    <= 8'h00;
            valid   <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (sync2.cs_n) begin
                bit_cnt <= 3'd0;   // re-align byte boundary, discard partial byte
            end else if (sclk_rise) begin
                if (bit_cnt == 3'd7) begin
                    data    <= {shift, sync2.mosi};
                    valid   <= 1'b1;
                    bit_cnt <= 3'd0;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
                shift <= {shift[5:0], sync2.mosi};
            end
        end
    end

endmodule
