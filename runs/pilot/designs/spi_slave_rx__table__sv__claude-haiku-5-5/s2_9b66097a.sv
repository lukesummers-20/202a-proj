module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // 3-stage synchronizers for sclk (third stage used for edge detection),
    // 2-stage for mosi and cs_n, all aligned to the same delay.
    logic sclk_s1, sclk_s2, sclk_s3;
    logic mosi_s1, mosi_s2;
    logic cs_s1,   cs_s2;

    logic       sclk_rise;
    logic [7:0] shift_reg;
    logic [2:0] bit_count;

    always_ff @(posedge clk) begin
        sclk_s1 <= sclk;
        sclk_s2 <= sclk_s1;
        sclk_s3 <= sclk_s2;
        mosi_s1 <= mosi;
        mosi_s2 <= mosi_s1;
        cs_s1   <= cs_n;
        cs_s2   <= cs_s1;
    end

    assign sclk_rise = sclk_s2 & ~sclk_s3;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 8'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end
        else if (cs_s2) begin
            // E1: chip deselected, realign byte boundary
            bit_count <= 3'd0;
            valid     <= 1'b0;
        end
        else if (sclk_rise && (bit_count < 3'd7)) begin
            // E2: shift in bit
            shift_reg <= {shift_reg[6:0], mosi_s2};
            bit_count <= bit_count + 3'd1;
            valid     <= 1'b0;
        end
        else if (sclk_rise && (bit_count == 3'd7)) begin
            // E3: 8th bit completes byte
            data      <= {shift_reg[6:0], mosi_s2};
            valid     <= 1'b1;
            bit_count <= 3'd0;
        end
        else begin
            // E4
            valid <= 1'b0;
        end
    end

endmodule
