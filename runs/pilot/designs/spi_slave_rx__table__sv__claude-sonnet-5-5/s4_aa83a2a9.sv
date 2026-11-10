module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    logic [1:0] sclk_sync;
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;
    logic       sclk_prev;
    logic [6:0] shift_reg;
    logic [2:0] bit_count;

    logic sclk_s, mosi_s, cs_s;
    logic sclk_rise;

    always_comb begin
        sclk_s    = sclk_sync[1];
        mosi_s    = mosi_sync[1];
        cs_s      = cs_sync[1];
        sclk_rise = sclk_sync[1] & ~sclk_prev;
    end

    always_ff @(posedge clk) begin
        sclk_sync <= {sclk_sync[0], sclk};
        mosi_sync <= {mosi_sync[0], mosi};
        cs_sync   <= {cs_sync[0], cs_n};
        sclk_prev <= sclk_sync[1];

        if (!rst_n) begin
            bit_count <= 3'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
            shift_reg <= 7'd0;
        end else begin
            valid <= 1'b0;
            if (cs_s) begin
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count == 3'd7) begin
                    data      <= {shift_reg, mosi_s};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end else begin
                    shift_reg <= {shift_reg[5:0], mosi_s};
                    bit_count <= bit_count + 3'd1;
                end
            end
        end
    end

endmodule
