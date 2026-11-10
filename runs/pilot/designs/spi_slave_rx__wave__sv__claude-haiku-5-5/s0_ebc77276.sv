module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Two-stage synchronizers plus one extra stage for edge detection
    logic [2:0] sclk_sync;
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;

    // Shift and bit-count state
    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;

    logic sclk_rise;
    logic sclk_s;
    logic mosi_s;
    logic cs_s;

    assign sclk_s   = sclk_sync[1];
    assign mosi_s   = mosi_sync[1];
    assign cs_s     = cs_sync[1];
    assign sclk_rise = sclk_sync[1] & ~sclk_sync[2];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_sync <= '0;
            mosi_sync <= '0;
            cs_sync   <= '1;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            mosi_sync <= {mosi_sync[0], mosi};
            cs_sync   <= {cs_sync[0], cs_n};
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            shift_reg <= '0;
            bit_cnt   <= '0;
            data      <= '0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (cs_s) begin
                // Chip deselected: discard any partial byte and re-align
                bit_cnt <= '0;
            end else if (sclk_rise) begin
                shift_reg <= {shift_reg[6:0], mosi_s};
                if (bit_cnt == 3'd7) begin
                    bit_cnt <= '0;
                    data    <= {shift_reg[6:0], mosi_s};
                    valid   <= 1'b1;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
