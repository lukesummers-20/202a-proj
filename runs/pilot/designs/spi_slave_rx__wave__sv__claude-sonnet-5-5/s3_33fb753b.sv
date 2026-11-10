module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    logic [2:0] sclk_sync;
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;

    logic [6:0] shift;
    logic [2:0] bit_cnt;

    logic sclk_rise;

    assign sclk_rise = sclk_sync[1] & ~sclk_sync[2];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            mosi_sync <= 2'b00;
            cs_sync   <= 2'b11;
            shift     <= 7'd0;
            bit_cnt   <= 3'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            mosi_sync <= {mosi_sync[0], mosi};
            cs_sync   <= {cs_sync[0], cs_n};

            valid <= 1'b0;

            if (cs_sync[1]) begin
                bit_cnt <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_cnt == 3'd7) begin
                    data    <= {shift, mosi_sync[1]};
                    valid   <= 1'b1;
                    bit_cnt <= 3'd0;
                end else begin
                    shift   <= {shift[5:0], mosi_sync[1]};
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
