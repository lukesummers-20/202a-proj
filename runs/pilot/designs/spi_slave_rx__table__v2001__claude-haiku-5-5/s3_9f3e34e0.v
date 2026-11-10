module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);

    // Two-stage synchronizers for asynchronous SPI inputs
    reg sclk_s1, sclk_s2, sclk_d;
    reg mosi_s1, mosi_s2;
    reg cs_s1,   cs_s2;

    // Shift state
    reg [6:0] shift_reg;
    reg [2:0] bit_count;

    wire sclk_rise;
    assign sclk_rise = sclk_s2 & ~sclk_d;

    always @(posedge clk) begin
        if (!rst_n) begin
            sclk_s1   <= 1'b0;
            sclk_s2   <= 1'b0;
            sclk_d    <= 1'b0;
            mosi_s1   <= 1'b0;
            mosi_s2   <= 1'b0;
            cs_s1     <= 1'b1;
            cs_s2     <= 1'b1;
            shift_reg <= 7'd0;
            bit_count <= 3'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            // synchronize inputs
            sclk_s1 <= sclk;
            sclk_s2 <= sclk_s1;
            sclk_d  <= sclk_s2;
            mosi_s1 <= mosi;
            mosi_s2 <= mosi_s1;
            cs_s1   <= cs_n;
            cs_s2   <= cs_s1;

            // default: valid is a single-cycle pulse
            valid <= 1'b0;

            if (cs_s2) begin
                // E1: chip deselected, idle
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count < 3'd7) begin
                    // E2: shift in bit
                    shift_reg <= {shift_reg[5:0], mosi_s2};
                    bit_count <= bit_count + 3'd1;
                end else begin
                    // E3: 8th bit completes byte
                    data      <= {shift_reg[6:0], mosi_s2};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end
            end
            // E4 (otherwise): valid already cleared, others unchanged
        end
    end

endmodule
