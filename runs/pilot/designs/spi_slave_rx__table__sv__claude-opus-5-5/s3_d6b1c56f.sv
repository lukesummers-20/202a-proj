module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizer record: three stages of sclk (two sync + one edge-detect
    // history), two stages each of mosi and cs_n.
    typedef struct packed {
        logic [2:0] sclk_sr;
        logic [1:0] mosi_sr;
        logic [1:0] csn_sr;
    } sync_t;

    sync_t      sync_q;
    logic [6:0] shift_reg;
    logic [2:0] bit_count;

    logic sclk_rise;
    logic mosi_s;
    logic csn_s;

    // Synchronizer chain
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sync_q.sclk_sr <= 3'b000;
            sync_q.mosi_sr <= 2'b00;
            sync_q.csn_sr  <= 2'b11;
        end else begin
            sync_q.sclk_sr <= {sync_q.sclk_sr[1:0], sclk};
            sync_q.mosi_sr <= {sync_q.mosi_sr[0],   mosi};
            sync_q.csn_sr  <= {sync_q.csn_sr[0],    cs_n};
        end
    end

    // Derived synchronized signals
    always_comb begin
        sclk_rise = sync_q.sclk_sr[1] & ~sync_q.sclk_sr[2];
        mosi_s    = sync_q.mosi_sr[1];
        csn_s     = sync_q.csn_sr[1];
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
            if (csn_s) begin
                bit_count <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_count == 3'd7) begin
                    data      <= {shift_reg, mosi_s};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end else begin
                    shift_reg <= {shift_reg[5:0], mosi_s};
                    bit_count <= bit_count + 3'd1;
                end
            end
        end
    end

endmodule
