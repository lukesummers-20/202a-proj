module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    typedef struct packed {
        logic s1;
        logic s2;
    } sync_t;

    sync_t sclk_sync, mosi_sync, cs_sync;
    logic  sclk_prev;
    logic  sclk_s, mosi_s, cs_s;
    logic  sclk_rise;

    logic [2:0] bit_count;
    logic [7:0] shift_reg;

    always_ff @(posedge clk) begin
        sclk_sync <= '{s1: sclk,  s2: sclk_sync.s1};
        mosi_sync <= '{s1: mosi,  s2: mosi_sync.s1};
        // cs_n resets to idle-high synchronizer state
        cs_sync   <= '{s1: cs_n,  s2: cs_sync.s1};
        sclk_prev <= sclk_s;
    end

    always_comb begin
        sclk_s    = sclk_sync.s2;
        mosi_s    = mosi_sync.s2;
        cs_s      = cs_sync.s2;
        sclk_rise = sclk_s & ~sclk_prev;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
            shift_reg <= 8'd0;
        end else begin
            valid <= 1'b0;
            if (cs_s) begin
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count == 3'd7) begin
                    data      <= {shift_reg[6:0], mosi_s};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end else begin
                    shift_reg <= {shift_reg[6:0], mosi_s};
                    bit_count <= bit_count + 3'd1;
                end
            end
        end
    end

endmodule
