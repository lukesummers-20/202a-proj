module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Two-stage synchronizers for asynchronous SPI inputs
    logic [1:0] sclk_sync;
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;

    // Delayed synchronized sclk for edge detection
    logic       sclk_d;

    // Rising-edge detect of synchronized sclk
    logic       sclk_rise;

    // Receive state
    logic [2:0] bit_cnt;
    logic [7:0] shift_reg;

    assign sclk_rise = sclk_sync[1] & ~sclk_d;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_sync <= 2'b00;
            mosi_sync <= 2'b00;
            cs_sync   <= 2'b11;
            sclk_d    <= 1'b0;
        end
        else begin
            sclk_sync <= {sclk_sync[0], sclk};
            mosi_sync <= {mosi_sync[0], mosi};
            cs_sync   <= {cs_sync[0], cs_n};
            sclk_d    <= sclk_sync[1];
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_cnt   <= 3'd0;
            shift_reg <= 8'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end
        else begin
            valid <= 1'b0;

            if (cs_sync[1]) begin
                // Idle: clear bit count
                bit_cnt <= 3'd0;
            end
            else if (sclk_rise) begin
                // Sample MOSI on sclk rising edge (MSB first)
                shift_reg <= {shift_reg[6:0], mosi_sync[1]};
                if (bit_cnt == 3'd7) begin
                    bit_cnt <= 3'd0;
                    data    <= {shift_reg[6:0], mosi_sync[1]};
                    valid   <= 1'b1;
                end
                else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
