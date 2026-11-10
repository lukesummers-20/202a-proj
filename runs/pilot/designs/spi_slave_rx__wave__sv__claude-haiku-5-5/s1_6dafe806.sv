module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Two-flop synchronizers for asynchronous inputs
    logic sclk_m, sclk_s, sclk_d;
    logic mosi_m, mosi_s;
    logic cs_m,   cs_s;

    // Shift/bit tracking
    logic [7:0] shreg;
    logic [2:0] bit_cnt;
    logic       rise;
    logic [7:0] next_byte;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_m <= 1'b0;
            sclk_s <= 1'b0;
            sclk_d <= 1'b0;
            mosi_m <= 1'b0;
            mosi_s <= 1'b0;
            cs_m   <= 1'b1;
            cs_s   <= 1'b1;
        end else begin
            sclk_m <= sclk;
            sclk_s <= sclk_m;
            sclk_d <= sclk_s;
            mosi_m <= mosi;
            mosi_s <= mosi_m;
            cs_m   <= cs_n;
            cs_s   <= cs_m;
        end
    end

    always_comb begin
        rise      = sclk_s & ~sclk_d;
        next_byte = {shreg[6:0], mosi_s};
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            shreg   <= 8'd0;
            bit_cnt <= 3'd0;
            data    <= 8'd0;
            valid   <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (cs_s) begin
                // Deselected: discard any partial byte and re-align
                bit_cnt <= 3'd0;
            end else if (rise) begin
                shreg <= next_byte;
                if (bit_cnt == 3'd7) begin
                    bit_cnt <= 3'd0;
                    data    <= next_byte;
                    valid   <= 1'b1;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
