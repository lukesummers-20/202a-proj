module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizer chains (clk domain)
    logic sclk_a, sclk_b, sclk_c;
    logic mosi_a, mosi_b;
    logic cs_a, cs_b;

    // Shift/count state
    logic [7:0] shreg;
    logic [2:0] bit_cnt;

    // Edge detection and sampled inputs
    logic sclk_rise;
    logic [7:0] byte_next;

    always_comb begin
        sclk_rise = sclk_b & ~sclk_c;
        byte_next = {shreg[6:0], mosi_b};
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_a  <= 1'b0;
            sclk_b  <= 1'b0;
            sclk_c  <= 1'b0;
            mosi_a  <= 1'b0;
            mosi_b  <= 1'b0;
            cs_a    <= 1'b1;
            cs_b    <= 1'b1;
            shreg   <= 8'h00;
            bit_cnt <= 3'd0;
            data    <= 8'h00;
            valid   <= 1'b0;
        end else begin
            // Synchronize asynchronous inputs
            sclk_a <= sclk;
            sclk_b <= sclk_a;
            sclk_c <= sclk_b;
            mosi_a <= mosi;
            mosi_b <= mosi_a;
            cs_a   <= cs_n;
            cs_b   <= cs_a;

            // Default: valid is a one-cycle pulse
            valid <= 1'b0;

            if (cs_b) begin
                // Idle: clear bit count
                bit_cnt <= 3'd0;
            end else if (sclk_rise) begin
                // Sample MOSI on SPI rising edge
                shreg <= byte_next;
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
