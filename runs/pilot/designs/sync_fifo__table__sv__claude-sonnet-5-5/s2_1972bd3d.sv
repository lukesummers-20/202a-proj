module sync_fifo (
    input  logic       clk,      // clock
    input  logic       rst_n,    // active-low synchronous reset
    input  logic       wr_en,    // write request
    input  logic [7:0] wr_data,  // data to write
    input  logic       rd_en,    // read request
    output logic [7:0] rd_data,  // data of the most recent accepted read (registered)
    output logic       full,     // 1 when 4 items are stored
    output logic       empty     // 1 when 0 items are stored
);

    logic [7:0] mem [0:3];
    logic [1:0] wp, rp;
    logic [2:0] cnt;
    logic       do_wr, do_rd;
    logic [2:0] cnt_nxt;

    always_comb begin
        do_wr = wr_en && !full;
        do_rd = rd_en && !empty;
        cnt_nxt = cnt;
        if (do_wr && !do_rd)
            cnt_nxt = cnt + 3'd1;
        else if (do_rd && !do_wr)
            cnt_nxt = cnt - 3'd1;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wp      <= 2'd0;
            rp      <= 2'd0;
            cnt     <= 3'd0;
            rd_data <= 8'd0;
            empty   <= 1'b1;
            full    <= 1'b0;
        end else begin
            if (do_wr) begin
                mem[wp] <= wr_data;
                wp      <= wp + 2'd1;
            end
            if (do_rd) begin
                rd_data <= mem[rp];
                rp      <= rp + 2'd1;
            end
            cnt   <= cnt_nxt;
            empty <= (cnt_nxt == 3'd0);
            full  <= (cnt_nxt == 3'd4);
        end
    end

endmodule
