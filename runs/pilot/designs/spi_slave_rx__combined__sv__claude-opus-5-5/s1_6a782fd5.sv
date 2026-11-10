module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizer chains: stages [0] and [1] form the 2-flop synchronizer.
    // sclk_sync[2] is an extra history stage used for rising-edge detection.
    logic [2:0] sclk_sync;
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;

    logic [6:0] shift_reg;
    logic [2:0] bit_count;

    logic sclk_rise;
    logic mosi_s;
    logic cs_n_s;

    always_comb begin
        sclk_rise = sclk_sync[1] & ~sclk_sync[2];
        mosi_s    = mosi_sync[1];
        cs_n_s    = cs_sync[1];
    end

    // Input synchronizers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            mosi_sync <= 2'b00;
            cs_sync   <= 2'b11;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            mosi_sync <= {mosi_sync[0], mosi};
            cs_sync   <= {cs_sync[0], cs_n};
        end
    end

    // Receiver core
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else if (cs_n_s) begin
            bit_count <= 3'd0;
            valid     <= 1'b0;
        end else if (sclk_rise) begin
            if (bit_count == 3'd7) begin
                data      <= {shift_reg, mosi_s};
                valid     <= 1'b1;
                bit_count <= 3'd0;
            end else begin
                shift_reg <= {shift_reg[5:0], mosi_s};
                bit_count <= bit_count + 3'd1;
                valid     <= 1'b0;
            end
        end else begin
            valid <= 1'b0;
        end
    end

endmodule
