module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // 2-stage synchronizers for asynchronous SPI inputs
    logic sclk_s1, sclk_s2, sclk_prev;
    logic mosi_s1, mosi_s2;
    logic cs_s1,   cs_s2;

    logic       sclk_rise;
    logic [6:0] shift_reg;
    logic [2:0] bit_count;

    always_ff @(posedge clk) begin
        sclk_s1  <= sclk;
        sclk_s2  <= sclk_s1;
        sclk_prev <= sclk_s2;
        mosi_s1  <= mosi;
        mosi_s2  <= mosi_s1;
        cs_s1    <= cs_n;
        cs_s2    <= cs_s1;
    end

    assign sclk_rise = sclk_s2 & ~sclk_prev;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
            shift_reg <= 7'd0;
        end
        else begin
            valid <= 1'b0; // default (E4)
            if (cs_s2) begin
                // E1: chip deselected, realign byte boundary
                bit_count <= 3'd0;
            end
            else if (sclk_rise) begin
                if (bit_count < 3'd7) begin
                    // E2: shift in bit
                    shift_reg <= {shift_reg[5:0], mosi_s2};
                    bit_count <= bit_count + 3'd1;
                end
                else begin
                    // E3: final bit, complete byte
                    data      <= {shift_reg[5:0], mosi_s2};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end
            end
        end
    end

endmodule
