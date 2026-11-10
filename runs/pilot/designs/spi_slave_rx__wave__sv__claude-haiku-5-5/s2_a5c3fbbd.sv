module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizers (two flops each) and edge detection state
    logic sclk_m, sclk_s, sclk_p;   // sclk: meta, synced, previous synced
    logic mosi_m, mosi_s;           // mosi: meta, synced
    logic cs_m,   cs_s;             // cs_n: meta, synced

    logic       sclk_rise;
    logic [2:0] bit_cnt;
    logic [7:0] shift_reg;

    assign sclk_rise = sclk_s & ~sclk_p;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_m    <= 1'b0;
            sclk_s    <= 1'b0;
            sclk_p    <= 1'b0;
            mosi_m    <= 1'b0;
            mosi_s    <= 1'b0;
            cs_m      <= 1'b1;
            cs_s      <= 1'b1;
            bit_cnt   <= 3'd0;
            shift_reg <= 8'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            // Synchronize asynchronous inputs
            sclk_m <= sclk;
            sclk_s <= sclk_m;
            sclk_p <= sclk_s;
            mosi_m <= mosi;
            mosi_s <= mosi_m;
            cs_m   <= cs_n;
            cs_s   <= cs_m;

            // Default: valid is a one-cycle pulse
            valid <= 1'b0;

            if (cs_s) begin
                // Chip deselected: discard any partial byte
                bit_cnt <= 3'd0;
            end else if (sclk_rise) begin
                // Sample MOSI on sclk rising edge, MSB first
                shift_reg <= {shift_reg[6:0], mosi_s};
                if (bit_cnt == 3'd7) begin
                    data    <= {shift_reg[6:0], mosi_s};
                    valid   <= 1'b1;
                    bit_cnt <= 3'd0;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
