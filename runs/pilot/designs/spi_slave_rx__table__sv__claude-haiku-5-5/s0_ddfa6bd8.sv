module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // 2-stage synchronizers for asynchronous inputs
    logic [1:0] sclk_sync;
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;
    logic       sclk_prev;

    logic       sclk_s;
    logic       mosi_s;
    logic       cs_s;
    logic       sclk_rise;

    logic [2:0] bit_count;
    logic [6:0] shift_reg;

    always_ff @(posedge clk) begin
        sclk_sync <= {sclk_sync[0], sclk};
        mosi_sync <= {mosi_sync[0], mosi};
        cs_sync   <= {cs_sync[0], cs_n};
        sclk_prev <= sclk_s;
    end

    always_comb begin
        sclk_s    = sclk_sync[1];
        mosi_s    = mosi_sync[1];
        cs_s      = cs_sync[1];
        sclk_rise = sclk_s & ~sclk_prev;
    end

    // Receive FSM (events E0..E4)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;                       // E4 default
            if (cs_s) begin
                bit_count <= 3'd0;               // E1
            end else if (sclk_rise) begin
                if (bit_count < 3'd7) begin      // E2
                    shift_reg <= {shift_reg[5:0], mosi_s};
                    bit_count <= bit_count + 3'd1;
                end else begin                   // E3
                    data      <= {shift_reg[6:0], mosi_s};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end
            end
        end
    end

endmodule
