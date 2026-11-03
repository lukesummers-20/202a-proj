// MUTANT m4_ignore_cs: cs_n never resets the bit counter
module spi_slave_rx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       sclk,
    input  logic       mosi,
    input  logic       cs_n,
    output logic [7:0] data,
    output logic       valid
);
    // 2-stage synchronizers (plus one extra stage on sclk for edge detection)
    logic [2:0] sclk_sync;
    logic [1:0] mosi_sync, cs_sync;

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

    wire sclk_rise = (sclk_sync[1] == 1'b1) && (sclk_sync[2] == 1'b0);
    wire cs_active = (cs_sync[1] == 1'b0);
    wire mosi_s    = mosi_sync[1];

    logic [2:0] bit_cnt;
    logic [6:0] shreg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_cnt <= 3'd0;
            shreg   <= 7'd0;
            data    <= 8'd0;
            valid   <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (1'b0) begin
                bit_cnt <= 3'd0;
            end else if (sclk_rise) begin
                if (bit_cnt == 3'd7) begin
                    data    <= {shreg, mosi_s};
                    valid   <= 1'b1;
                    bit_cnt <= 3'd0;
                end else begin
                    shreg   <= {shreg[5:0], mosi_s};
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end
endmodule
