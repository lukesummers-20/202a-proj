module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);

    // 2-stage synchronizers for asynchronous SPI inputs
    reg [1:0] sclk_sync;
    reg [1:0] mosi_sync;
    reg [1:0] cs_sync;
    reg       sclk_prev;

    // Receive state
    reg [2:0] bit_count;
    reg [6:0] shift_reg;

    wire sclk_s   = sclk_sync[1];
    wire mosi_s   = mosi_sync[1];
    wire cs_s     = cs_sync[1];
    wire sclk_rise = sclk_s & ~sclk_prev;

    // Synchronizer and edge-detect history (no reset needed)
    always @(posedge clk) begin
        sclk_sync <= {sclk_sync[0], sclk};
        mosi_sync <= {mosi_sync[0], mosi};
        cs_sync   <= {cs_sync[0], cs_n};
        sclk_prev <= sclk_s;
    end

    // Receive logic
    always @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (cs_s) begin
                // E1: chip deselected, realign byte boundary
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count < 3'd7) begin
                    // E2: shift in bit
                    shift_reg <= {shift_reg[5:0], mosi_s};
                    bit_count <= bit_count + 3'd1;
                end else begin
                    // E3: 8th bit, complete byte
                    data      <= {shift_reg[6:0], mosi_s};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end
            end
            // E4: otherwise valid already cleared, everything else holds
        end
    end

endmodule
