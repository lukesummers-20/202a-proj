module spi_slave_rx (
    input  logic       clk,    // system clock
    input  logic       rst_n,  // active-low synchronous reset
    input  logic       sclk,   // SPI clock from master (asynchronous to clk)
    input  logic       mosi,   // master-out slave-in data
    input  logic       cs_n,   // active-low chip select
    output logic [7:0] data,   // last complete byte received
    output logic       valid   // one-clk-cycle pulse when data is updated
);

    // Two-stage synchronizers for asynchronous SPI inputs
    logic sclk_m, sclk_s;
    logic mosi_m, mosi_s;
    logic cs_m,   cs_s;

    // Previous synchronized sclk for edge detection
    logic sclk_prev;

    // Receive state
    logic [2:0] bit_count;
    logic [6:0] shift_reg;

    logic sclk_rise;
    assign sclk_rise = sclk_s & ~sclk_prev;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_m    <= 1'b0;
            sclk_s    <= 1'b0;
            mosi_m    <= 1'b0;
            mosi_s    <= 1'b0;
            cs_m      <= 1'b1;
            cs_s      <= 1'b1;
            sclk_prev <= 1'b0;
        end else begin
            sclk_m    <= sclk;
            sclk_s    <= sclk_m;
            mosi_m    <= mosi;
            mosi_s    <= mosi_m;
            cs_m      <= cs_n;
            cs_s      <= cs_m;
            sclk_prev <= sclk_s;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bit_count <= 3'd0;
            shift_reg <= 7'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            if (cs_s) begin
                // E1: idle, bit count cleared, data unchanged
                bit_count <= 3'd0;
                valid     <= 1'b0;
            end else if (sclk_rise) begin
                if (bit_count < 3'd7) begin
                    // E2: shift in bit
                    shift_reg <= {shift_reg[5:0], mosi_s};
                    bit_count <= bit_count + 3'd1;
                    valid     <= 1'b0;
                end else begin
                    // E3: eighth bit, complete byte
                    data      <= {shift_reg[6:0], mosi_s};
                    valid     <= 1'b1;
                    bit_count <= 3'd0;
                end
            end else begin
                // E4: otherwise
                valid <= 1'b0;
            end
        end
    end

endmodule
