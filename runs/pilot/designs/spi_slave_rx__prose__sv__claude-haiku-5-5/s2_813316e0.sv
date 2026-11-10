module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizers (two flops each)
    logic sclk_s1, sclk_s2, sclk_prev;
    logic mosi_s1, mosi_s2;
    logic cs_s1, cs_s2;

    // Shift / counter state
    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;

    logic sclk_rise;
    logic [7:0] byte_next;

    assign sclk_rise = sclk_s2 & ~sclk_prev;
    assign byte_next = {shift_reg[6:0], mosi_s2};

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_s1   <= 1'b0;
            sclk_s2   <= 1'b0;
            sclk_prev <= 1'b0;
            mosi_s1   <= 1'b0;
            mosi_s2   <= 1'b0;
            cs_s1     <= 1'b1;
            cs_s2     <= 1'b1;
            shift_reg <= 8'h00;
            bit_cnt   <= 3'd0;
            data      <= 8'h00;
            valid     <= 1'b0;
        end else begin
            // Synchronize asynchronous SPI inputs
            sclk_s1   <= sclk;
            sclk_s2   <= sclk_s1;
            sclk_prev <= sclk_s2;
            mosi_s1   <= mosi;
            mosi_s2   <= mosi_s1;
            cs_s1     <= cs_n;
            cs_s2     <= cs_s1;

            // Default: valid is a single-cycle pulse
            valid <= 1'b0;

            if (cs_s2) begin
                // Idle: clear bit count
                bit_cnt   <= 3'd0;
            end else if (sclk_rise) begin
                // Sample mosi on sclk rising edge, MSB first
                shift_reg <= byte_next;
                if (bit_cnt == 3'd7) begin
                    data    <= byte_next;
                    valid   <= 1'b1;
                    bit_cnt <= 3'd0;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
