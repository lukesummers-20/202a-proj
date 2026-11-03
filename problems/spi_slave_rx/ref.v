// Verilog-2001 reference (never shown to the model). Same behaviour as ref.sv; exists so the
// v2001 header, dialect-compliance check and Icarus/Verilator v2001 path are validated too.
module spi_slave_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sclk,
    input  wire       mosi,
    input  wire       cs_n,
    output reg  [7:0] data,
    output reg        valid
);
    reg [2:0] sclk_sync;
    reg [1:0] mosi_sync, cs_sync;

    always @(posedge clk) begin
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

    wire sclk_rise = sclk_sync[1] & ~sclk_sync[2];
    wire cs_active = ~cs_sync[1];
    wire mosi_s    = mosi_sync[1];

    reg [2:0] bit_cnt;
    reg [6:0] shreg;

    always @(posedge clk) begin
        if (!rst_n) begin
            bit_cnt <= 3'd0;
            shreg   <= 7'd0;
            data    <= 8'd0;
            valid   <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (!cs_active) begin
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
