module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizers (2-stage) for asynchronous SPI inputs
    logic [1:0] sclk_sync;
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;
    logic       sclk_d;      // delayed synchronized sclk for edge detection

    logic       sclk_rise;
    logic [6:0] shift_reg;
    logic [2:0] bit_count;

    always_ff @(posedge clk) begin
        sclk_sync <= {sclk_sync[0], sclk};
        mosi_sync <= {mosi_sync[0], mosi};
        cs_sync   <= {cs_sync[0], cs_n};
        sclk_d    <= sclk_sync[1];
    end

    assign sclk_rise = sclk_sync[1] & ~sclk_d;

    // Receive state machine (events E0..E4)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end
        else if (cs_sync[1]) begin
            // E1: chip deselected, realign byte boundary
            bit_count <= 3'd0;
            valid     <= 1'b0;
        end
        else if (sclk_rise) begin
            if (bit_count < 3'd7) begin
                // E2: shift in bit
                shift_reg <= {shift_reg[5:0], mosi_sync[1]};
                bit_count <= bit_count + 3'd1;
                valid     <= 1'b0;
            end
            else begin
                // E3: 8th bit, byte complete
                data      <= {shift_reg[6:0], mosi_sync[1]};
                valid     <= 1'b1;
                bit_count <= 3'd0;
            end
        end
        else begin
            // E4: idle
            valid <= 1'b0;
        end
    end

endmodule
