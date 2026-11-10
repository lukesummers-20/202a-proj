module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizers (2-stage) plus one extra stage for edge detection
    logic sclk_q1, sclk_q2, sclk_q3;
    logic mosi_q1, mosi_q2;
    logic cs_q1,   cs_q2;

    logic       sclk_rise;
    logic [2:0] bit_count;
    logic [6:0] shift_reg;

    always_ff @(posedge clk) begin
        sclk_q1 <= sclk;
        sclk_q2 <= sclk_q1;
        sclk_q3 <= sclk_q2;
        mosi_q1 <= mosi;
        mosi_q2 <= mosi_q1;
        cs_q1   <= cs_n;
        cs_q2   <= cs_q1;
    end

    assign sclk_rise = sclk_q2 & ~sclk_q3;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end
        else begin
            valid <= 1'b0;
            if (cs_q2) begin
                // E1: idle, clear bit count
                bit_count <= 3'd0;
            end
            else if (sclk_rise) begin
                if (bit_count < 3'd7) begin
                    // E2: shift in bit
                    shift_reg <= {shift_reg[5:0], mosi_q2};
                    bit_count <= bit_count + 3'd1;
                end
                else begin
                    // E3: byte complete
                    data      <= {shift_reg[6:0], mosi_q2};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end
            end
        end
    end

endmodule
