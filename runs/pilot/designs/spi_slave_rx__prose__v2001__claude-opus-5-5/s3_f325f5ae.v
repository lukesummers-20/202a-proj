module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);

    reg [2:0] sclk_r;
    reg [1:0] mosi_r;
    reg [1:0] cs_r;
    reg [2:0] bit_cnt;
    reg [6:0] shreg;

    wire sclk_rise = sclk_r[1] & ~sclk_r[2];
    wire mosi_s    = mosi_r[1];
    wire cs_active = ~cs_r[1];

    always @(posedge clk) begin
        if (!rst_n) begin
            sclk_r  <= 3'b000;
            mosi_r  <= 2'b00;
            cs_r    <= 2'b11;
            bit_cnt <= 3'd0;
            shreg   <= 7'd0;
            data    <= 8'd0;
            valid   <= 1'b0;
        end else begin
            sclk_r <= {sclk_r[1:0], sclk};
            mosi_r <= {mosi_r[0], mosi};
            cs_r   <= {cs_r[0], cs_n};
            valid  <= 1'b0;

            if (!cs_active) begin
                bit_cnt <= 3'd0;
            end else if (sclk_rise) begin
                shreg   <= {shreg[5:0], mosi_s};
                bit_cnt <= bit_cnt + 3'd1;
                if (bit_cnt == 3'd7) begin
                    data  <= {shreg, mosi_s};
                    valid <= 1'b1;
                end
            end
        end
    end

endmodule
