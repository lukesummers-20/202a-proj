module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);

    reg [1:0] sclk_sync;
    reg [1:0] mosi_sync;
    reg [1:0] cs_sync;
    reg       sclk_prev;
    reg [6:0] shift;
    reg [2:0] cnt;

    wire sclk_s = sclk_sync[1];
    wire mosi_s = mosi_sync[1];
    wire cs_s   = cs_sync[1];
    wire sclk_rise = sclk_s & ~sclk_prev;

    always @(posedge clk) begin
        if (!rst_n) begin
            sclk_sync <= 2'b00;
            mosi_sync <= 2'b00;
            cs_sync   <= 2'b11;
            sclk_prev <= 1'b0;
            shift     <= 7'd0;
            cnt       <= 3'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            sclk_sync <= {sclk_sync[0], sclk};
            mosi_sync <= {mosi_sync[0], mosi};
            cs_sync   <= {cs_sync[0], cs_n};
            sclk_prev <= sclk_s;
            valid     <= 1'b0;

            if (cs_s) begin
                cnt <= 3'd0;
            end else if (sclk_rise) begin
                if (cnt == 3'd7) begin
                    data  <= {shift, mosi_s};
                    valid <= 1'b1;
                    cnt   <= 3'd0;
                end else begin
                    shift <= {shift[5:0], mosi_s};
                    cnt   <= cnt + 3'd1;
                end
            end
        end
    end

endmodule
