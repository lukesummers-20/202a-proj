module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizers for asynchronous SPI inputs (clk domain)
    reg sclk_q1, sclk_q2, sclk_q3;
    reg mosi_q1, mosi_q2;
    reg cs_q1, cs_q2;

    always @(posedge clk) begin
        sclk_q1 <= sclk;
        sclk_q2 <= sclk_q1;
        sclk_q3 <= sclk_q2;
        mosi_q1 <= mosi;
        mosi_q2 <= mosi_q1;
        cs_q1   <= cs_n;
        cs_q2   <= cs_q1;
    end

    // Rising edge detection on synchronized sclk
    wire sclk_rise = sclk_q2 & ~sclk_q3;

    reg [6:0] shift_reg;
    reg [2:0] bit_count;

    always @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
            shift_reg <= 7'd0;
        end else if (cs_q2) begin
            // E1: chip deselected, realign byte boundary
            bit_count <= 3'd0;
            valid     <= 1'b0;
        end else if (sclk_rise) begin
            if (bit_count < 3'd7) begin
                // E2: shift in bit
                shift_reg <= {shift_reg[5:0], mosi_q2};
                bit_count <= bit_count + 3'd1;
                valid     <= 1'b0;
            end else begin
                // E3: 8th bit completes the byte
                data      <= {shift_reg[6:0], mosi_q2};
                valid     <= 1'b1;
                bit_count <= 3'd0;
            end
        end else begin
            // E4
            valid <= 1'b0;
        end
    end

endmodule
