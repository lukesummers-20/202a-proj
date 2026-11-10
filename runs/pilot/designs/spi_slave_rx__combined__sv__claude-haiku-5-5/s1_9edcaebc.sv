module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Two-stage synchronizers for asynchronous SPI inputs (not reset)
    logic [1:0] sclk_sync;
    logic [1:0] mosi_sync;
    logic [1:0] cs_sync;

    always_ff @(posedge clk) begin
        sclk_sync <= {sclk_sync[0], sclk};
        mosi_sync <= {mosi_sync[0], mosi};
        cs_sync   <= {cs_sync[0], cs_n};
    end

    // Edge detection of synchronized sclk in clk domain
    logic sclk_prev;
    logic sclk_rise;

    always_ff @(posedge clk) begin
        if (!rst_n)
            sclk_prev <= 1'b0;
        else
            sclk_prev <= sclk_sync[1];
    end

    always_comb begin
        sclk_rise = sclk_sync[1] & ~sclk_prev;
    end

    // Receiver state
    logic [2:0] bit_count;
    logic [7:0] shift_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 8'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;  // E4 default

            if (cs_sync[1]) begin
                // E1: idle, clear bit count
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count == 3'd7) begin
                    // E3: complete byte
                    data      <= {shift_reg[6:0], mosi_sync[1]};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end else begin
                    // E2: shift in bit
                    shift_reg <= {shift_reg[6:0], mosi_sync[1]};
                    bit_count <= bit_count + 3'd1;
                end
            end
        end
    end

endmodule
