module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);
    reg sclk_s1, sclk_s2, sclk_d;
    reg mosi_s1, mosi_s2;
    reg cs_s1, cs_s2;
    reg [2:0] cnt;
    reg [7:0] shift;

    wire sclk_rise = sclk_s2 & ~sclk_d;
    wire [7:0] next_shift = {shift[6:0], mosi_s2};

    always @(posedge clk) begin
        if (!rst_n) begin
            sclk_s1 <= 1'b0;
            sclk_s2 <= 1'b0;
            sclk_d  <= 1'b0;
            mosi_s1 <= 1'b0;
            mosi_s2 <= 1'b0;
            cs_s1   <= 1'b1;
            cs_s2   <= 1'b1;
            cnt     <= 3'd0;
            shift   <= 8'd0;
            data    <= 8'd0;
            valid   <= 1'b0;
        end else begin
            sclk_s1 <= sclk;
            sclk_s2 <= sclk_s1;
            sclk_d  <= sclk_s2;
            mosi_s1 <= mosi;
            mosi_s2 <= mosi_s1;
            cs_s1   <= cs_n;
            cs_s2   <= cs_s1;
            valid   <= 1'b0;

            if (cs_s2) begin
                cnt   <= 3'd0;
                shift <= 8'd0;
            end else if (sclk_rise) begin
                shift <= next_shift;
                cnt   <= cnt + 3'd1;
                if (cnt == 3'd7) begin
                    data  <= next_shift;
                    valid <= 1'b1;
                end
            end
        end
    end
endmodule
