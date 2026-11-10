module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    logic [1:0] sclk_sync;
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;
    logic       sclk_prev;
    logic [6:0] shift;
    logic [2:0] cnt;

    logic sclk_s, mosi_s, cs_s;
    logic rise;

    assign sclk_s = sclk_sync[1];
    assign mosi_s = mosi_sync[1];
    assign cs_s   = cs_sync[1];
    assign rise   = sclk_s & ~sclk_prev;

    always_ff @(posedge clk) begin
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
                cnt   <= 3'd0;
                shift <= 7'd0;
            end else if (rise) begin
                shift <= {shift[5:0], mosi_s};
                cnt   <= cnt + 3'd1;
                if (cnt == 3'd7) begin
                    data  <= {shift, mosi_s};
                    valid <= 1'b1;
                end
            end
        end
    end

endmodule
