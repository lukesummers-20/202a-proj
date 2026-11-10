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
    logic sclk_meta, sclk_sync;
    logic mosi_meta, mosi_sync;
    logic cs_meta,   cs_sync;

    // Previous synchronized sclk level for edge detection
    logic sclk_prev;

    // Receive state
    logic [7:0] shift_reg;
    logic [2:0] bit_count;

    // Rising edge of synchronized sclk, evaluated in clk domain
    logic sclk_rise;
    assign sclk_rise = sclk_sync & ~sclk_prev;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_meta <= 1'b0;
            sclk_sync <= 1'b0;
            mosi_meta <= 1'b0;
            mosi_sync <= 1'b0;
            cs_meta   <= 1'b1;
            cs_sync   <= 1'b1;
            sclk_prev <= 1'b0;
            shift_reg <= 8'h00;
            bit_count <= 3'd0;
            data      <= 8'h00;
            valid     <= 1'b0;
        end else begin
            // Synchronize inputs
            sclk_meta <= sclk;
            sclk_sync <= sclk_meta;
            mosi_meta <= mosi;
            mosi_sync <= mosi_meta;
            cs_meta   <= cs_n;
            cs_sync   <= cs_meta;

            sclk_prev <= sclk_sync;

            if (cs_sync) begin
                // E1: idle, clear bit count
                bit_count <= 3'd0;
                valid     <= 1'b0;
            end else if (sclk_rise) begin
                if (bit_count < 3'd7) begin
                    // E2: shift in bit
                    shift_reg <= {shift_reg[6:0], mosi_sync};
                    bit_count <= bit_count + 3'd1;
                    valid     <= 1'b0;
                end else begin
                    // E3: eighth bit, complete byte
                    data      <= {shift_reg[6:0], mosi_sync};
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
