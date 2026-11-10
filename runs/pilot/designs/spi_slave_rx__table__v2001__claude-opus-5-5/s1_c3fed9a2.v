module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizers
    reg sclk_s1, sclk_s2, sclk_s3;
    reg mosi_s1, mosi_s2;
    reg cs_s1,   cs_s2;

    reg [6:0] shift_reg;
    reg [2:0] bit_count;

    wire sclk_rise = sclk_s2 & ~sclk_s3;

    // sclk / mosi synchronizers (free-running)
    always @(posedge clk) begin
        sclk_s1 <= sclk;
        sclk_s2 <= sclk_s1;
        sclk_s3 <= sclk_s2;
        mosi_s1 <= mosi;
        mosi_s2 <= mosi_s1;
    end

    // cs_n synchronizer, reset to inactive
    always @(posedge clk) begin
        if (!rst_n) begin
            cs_s1 <= 1'b1;
            cs_s2 <= 1'b1;
        end else begin
            cs_s1 <= cs_n;
            cs_s2 <= cs_s1;
        end
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
            if (cs_s2) begin
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count == 3'd7) begin
                    data      <= {shift_reg[6:0], mosi_s2};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end else begin
                    shift_reg <= {shift_reg[5:0], mosi_s2};
                    bit_count <= bit_count + 3'd1;
                end
            end
        end
    end

endmodule
