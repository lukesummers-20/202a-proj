module sync_fifo (
    input  wire       clk,      // clock
    input  wire       rst_n,    // active-low synchronous reset
    input  wire       wr_en,    // write request
    input  wire [7:0] wr_data,  // data to write
    input  wire       rd_en,    // read request
    output reg  [7:0] rd_data,  // data of the most recent accepted read (registered)
    output reg        full,     // 1 when 4 items are stored
    output reg        empty     // 1 when 0 items are stored
);

    localparam DEPTH = 4;

    reg [7:0] mem [0:DEPTH-1];
    reg [1:0] wp;
    reg [1:0] rp;
    reg [2:0] cnt;
    reg [2:0] cnt_n;
    reg       wr_acc;
    reg       rd_acc;

    // Accept decisions based on registered full/empty flags
    always @(*) begin
        wr_acc = wr_en && !full;
        rd_acc = rd_en && !empty;
    end

    // Next item count
    always @(*) begin
        if (wr_acc && !rd_acc)
            cnt_n = cnt + 3'd1;
        else if (rd_acc && !wr_acc)
            cnt_n = cnt - 3'd1;
        else
            cnt_n = cnt;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            wp      <= 2'd0;
            rp      <= 2'd0;
            cnt     <= 3'd0;
            rd_data <= 8'd0;
            full    <= 1'b0;
            empty   <= 1'b1;
        end else begin
            if (wr_acc) begin
                mem[wp] <= wr_data;
                wp      <= wp + 2'd1;
            end
            if (rd_acc) begin
                rd_data <= mem[rp];
                rp      <= rp + 2'd1;
            end
            cnt   <= cnt_n;
            full  <= (cnt_n == 3'd4);
            empty <= (cnt_n == 3'd0);
        end
    end

endmodule
