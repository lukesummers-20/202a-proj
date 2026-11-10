module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizer and edge-detect registers
    reg       sclk_s1, sclk_s2, sclk_s3;
    reg       mosi_s1, mosi_s2;
    reg       cs_s1,   cs_s2;

    // Shift/bit-count state
    reg [7:0] shreg;
    reg [2:0] bit_cnt;

    wire sclk_rise;
    wire sample_bit;
    wire [7:0] shifted;

    // Rising edge of sclk detected in clk domain (sclk_s2 is the aligned value)
    assign sclk_rise = sclk_s2 & ~sclk_s3;

    // mosi aligned with sclk_s2 timing (value present when rising edge was seen)
    assign sample_bit = mosi_s2;

    // Byte value including the bit being received now
    assign shifted = {shreg[6:0], sample_bit};

    always @(posedge clk) begin
        if (!rst_n) begin
            sclk_s1  <= 1'b0;
            sclk_s2  <= 1'b0;
            sclk_s3  <= 1'b0;
            mosi_s1  <= 1'b0;
            mosi_s2  <= 1'b0;
            cs_s1    <= 1'b1;
            cs_s2    <= 1'b1;
            shreg    <= 8'd0;
            bit_cnt  <= 3'd0;
            data     <= 8'd0;
            valid    <= 1'b0;
        end else begin
            // Synchronizers
            sclk_s1 <= sclk;
            sclk_s2 <= sclk_s1;
            sclk_s3 <= sclk_s2;
            mosi_s1 <= mosi;
            mosi_s2 <= mosi_s1;
            cs_s1   <= cs_n;
            cs_s2   <= cs_s1;

            // Default: valid is a single-cycle pulse
            valid <= 1'b0;

            if (cs_s2) begin
                // Idle: clear bit count
                bit_cnt <= 3'd0;
            end else if (sclk_rise) begin
                shreg <= shifted;
                if (bit_cnt == 3'd7) begin
                    data    <= shifted;
                    valid   <= 1'b1;
                    bit_cnt <= 3'd0;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
