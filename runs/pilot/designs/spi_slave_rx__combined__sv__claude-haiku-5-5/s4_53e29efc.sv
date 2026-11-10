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
    logic sclk_s1, sclk_s2, sclk_d;
    logic mosi_s1, mosi_s2;
    logic cs_s1, cs_s2;

    // Shift register and bit counter
    logic [7:0] shift_reg;
    logic [2:0] bit_count;

    logic sclk_rise;
    assign sclk_rise = sclk_s2 & ~sclk_d;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_s1   <= 1'b0;
            sclk_s2   <= 1'b0;
            sclk_d    <= 1'b0;
            mosi_s1   <= 1'b0;
            mosi_s2   <= 1'b0;
            cs_s1     <= 1'b1;
            cs_s2     <= 1'b1;
            shift_reg <= 8'h00;
            bit_count <= 3'd0;
            data      <= 8'h00;
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
                // idle: clear bit count, data and valid unchanged (valid already 0)
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count < 3'd7) begin
                    shift_reg <= {shift_reg[6:0], mosi_s2};
                    bit_count <= bit_count + 3'd1;
                end else begin
                    data      <= {shift_reg[6:0], mosi_s2};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end
            end
        end
    end

endmodule
