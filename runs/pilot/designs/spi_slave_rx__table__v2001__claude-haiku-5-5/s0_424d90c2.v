module spi_slave_rx (
    input  wire       clk,    // system clock
    input  wire       rst_n,  // active-low synchronous reset
    input  wire       sclk,   // SPI clock from master (asynchronous to clk)
    input  wire       mosi,   // master-out slave-in data
    input  wire       cs_n,   // active-low chip select
    output reg  [7:0] data,   // last complete byte received
    output reg        valid   // one-clk-cycle pulse when data is updated
);

    // Two-stage synchronizers (sclk has an extra delay stage for edge detection)
    reg [2:0] sclk_sync;
    reg [1:0] mosi_sync;
    reg [1:0] cs_sync;

    always @(posedge clk) begin
        sclk_sync <= {sclk_sync[1:0], sclk};
        mosi_sync <= {mosi_sync[0], mosi};
        cs_sync   <= {cs_sync[0], cs_n};
    end

    wire sclk_rise = sclk_sync[1] & ~sclk_sync[2];
    wire mosi_s    = mosi_sync[1];
    wire cs_s      = cs_sync[1];

    reg [2:0] bit_count;
    reg [6:0] shift_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;  // default: E4
            if (cs_s) begin
                // E1: idle, realign byte boundary
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count < 3'd7) begin
                    // E2: shift in bit
                    shift_reg <= {shift_reg[5:0], mosi_s};
                    bit_count <= bit_count + 3'd1;
                end else begin
                    // E3: byte complete
                    data      <= {shift_reg[6:0], mosi_s};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end
            end
        end
    end

endmodule
