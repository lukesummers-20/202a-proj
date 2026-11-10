module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizers
    logic [2:0] sclk_sync;   // [0],[1] sync stages, [2] previous for edge detect
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;

    logic       sclk_rise;
    logic       cs_active;
    logic       mosi_s;

    // Receive state
    logic [6:0] shift_reg;
    logic [2:0] bit_cnt;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            mosi_sync <= 2'b00;
            cs_sync   <= 2'b11;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            mosi_sync <= {mosi_sync[0], mosi};
            cs_sync   <= {cs_sync[0], cs_n};
        end
    end

    always_comb begin
        sclk_rise = sclk_sync[1] & ~sclk_sync[2];
        cs_active = ~cs_sync[1];
        mosi_s    = mosi_sync[1];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            shift_reg <= '0;
            bit_cnt   <= '0;
            data      <= '0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (!cs_active) begin
                bit_cnt   <= '0;
                shift_reg <= '0;
            end else if (sclk_rise) begin
                shift_reg <= {shift_reg[5:0], mosi_s};
                if (bit_cnt == 3'd7) begin
                    data    <= {shift_reg, mosi_s};
                    valid   <= 1'b1;
                    bit_cnt <= '0;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
