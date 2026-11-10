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
        logic [2:0] sclk_s;
        logic [1:0] mosi_s;
        logic [1:0] cs_s;
    } sync_t;

    sync_t      sync;
    logic [7:0] shreg;
    logic [2:0] bitcnt;
    logic       sclk_rise;
    logic       cs_active;
    logic       mosi_bit;

    always_comb begin
        sclk_rise = sync.sclk_s[1] & ~sync.sclk_s[2];
        cs_active = ~sync.cs_s[1];
        mosi_bit  = sync.mosi_s[1];
    end

    // Synchronizers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sync.sclk_s <= 3'b000;
            sync.mosi_s <= 2'b00;
            sync.cs_s   <= 2'b11;
        end else begin
            sync.sclk_s <= {sync.sclk_s[1:0], sclk};
            sync.mosi_s <= {sync.mosi_s[0], mosi};
            sync.cs_s   <= {sync.cs_s[0], cs_n};
        end
    end

    // Shift register / byte assembly
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            shreg  <= 8'h00;
            bitcnt <= 3'd0;
            data   <= 8'h00;
            valid  <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (!cs_active) begin
                bitcnt <= 3'd0;
            end else if (sclk_rise) begin
                shreg  <= {shreg[6:0], mosi_bit};
                bitcnt <= bitcnt + 3'd1;
                if (bitcnt == 3'd7) begin
                    data  <= {shreg[6:0], mosi_bit};
                    valid <= 1'b1;
                end
            end
        end
    end

endmodule
