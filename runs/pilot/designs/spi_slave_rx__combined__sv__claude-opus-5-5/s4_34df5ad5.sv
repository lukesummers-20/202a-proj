module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizer record
    typedef struct packed {
        logic sclk;
        logic mosi;
        logic cs_n;
    } spi_sig_t;

    spi_sig_t   sync1, sync2;
    logic       sclk_prev;
    logic [6:0] shift_reg;
    logic [2:0] bit_count;
    logic       sclk_rise;

    // 2-stage synchronizers + previous sclk for edge detection
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sync1     <= '{sclk: 1'b0, mosi: 1'b0, cs_n: 1'b1};
            sync2     <= '{sclk: 1'b0, mosi: 1'b0, cs_n: 1'b1};
            sclk_prev <= 1'b0;
        end else begin
            sync1     <= '{sclk: sclk, mosi: mosi, cs_n: cs_n};
            sync2     <= sync1;
            sclk_prev <= sync2.sclk;
        end
    end

    always_comb begin
        sclk_rise = sync2.sclk & ~sclk_prev;
    end

    // Receive logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (sync2.cs_n) begin
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count == 3'd7) begin
                    data      <= {shift_reg, sync2.mosi};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end else begin
                    shift_reg <= {shift_reg[5:0], sync2.mosi};
                    bit_count <= bit_count + 3'd1;
                end
            end
        end
    end

endmodule
