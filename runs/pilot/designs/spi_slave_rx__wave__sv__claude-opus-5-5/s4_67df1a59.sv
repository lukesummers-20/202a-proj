module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Synchronizer registers for the asynchronous SPI inputs
    typedef struct packed {
        logic [2:0] sclk;
        logic [1:0] mosi;
        logic [1:0] cs_n;
    } sync_t;

    sync_t      sync_q;
    logic       sclk_rise;
    logic       mosi_s;
    logic       cs_active;

    logic [6:0] shift_q;
    logic [2:0] bit_cnt_q;

    // Synchronizers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sync_q.sclk <= 3'b000;
            sync_q.mosi <= 2'b00;
            sync_q.cs_n <= 2'b11;
        end else begin
            sync_q.sclk <= {sync_q.sclk[1:0], sclk};
            sync_q.mosi <= {sync_q.mosi[0], mosi};
            sync_q.cs_n <= {sync_q.cs_n[0], cs_n};
        end
    end

    always_comb begin
        sclk_rise = sync_q.sclk[1] & ~sync_q.sclk[2];
        mosi_s    = sync_q.mosi[1];
        cs_active = ~sync_q.cs_n[1];
    end

    // Shift register, bit counter, output
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            shift_q   <= 7'd0;
            bit_cnt_q <= 3'd0;
            data      <= 8'h00;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (!cs_active) begin
                bit_cnt_q <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_cnt_q == 3'd7) begin
                    data      <= {shift_q, mosi_s};
                    valid     <= 1'b1;
                    bit_cnt_q <= 3'd0;
                end else begin
                    shift_q   <= {shift_q[5:0], mosi_s};
                    bit_cnt_q <= bit_cnt_q + 3'd1;
                end
            end
        end
    end

endmodule
