module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizers: 2 stages for each input, plus one extra stage on sclk
    // for edge detection.
    logic [2:0] sclk_s;
    logic [1:0] mosi_s;
    logic [1:0] cs_n_s;

    logic       sclk_rise;
    logic       mosi_q;
    logic       cs_n_q;

    logic [6:0] shift_reg;
    logic [2:0] bit_count;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_s <= 3'b000;
            mosi_s <= 2'b00;
            cs_n_s <= 2'b11;
        end else begin
            sclk_s <= {sclk_s[1:0], sclk};
            mosi_s <= {mosi_s[0], mosi};
            cs_n_s <= {cs_n_s[0], cs_n};
        end
    end

    always_comb begin
        sclk_rise = sclk_s[1] & ~sclk_s[2];
        mosi_q    = mosi_s[1];
        cs_n_q    = cs_n_s[1];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (cs_n_q) begin
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count == 3'd7) begin
                    data      <= {shift_reg, mosi_q};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end else begin
                    shift_reg <= {shift_reg[5:0], mosi_q};
                    bit_count <= bit_count + 3'd1;
                end
            end
        end
    end

endmodule
