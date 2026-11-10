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
    logic [1:0] wptr, rptr;
    logic [2:0] count;
    logic       do_wr, do_rd;

    always_comb begin
        full  = (count == 3'd4);
        empty = (count == 3'd0);
        do_wr = wr_en && !full;
        do_rd = rd_en && !empty;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wptr    <= 2'd0;
            rptr    <= 2'd0;
            count   <= 3'd0;
            rd_data <= 8'd0;
        end else begin
            if (do_wr) begin
                mem[wptr] <= wr_data;
                wptr      <= wptr + 2'd1;
            end
            if (do_rd) begin
                rd_data <= mem[rptr];
                rptr    <= rptr + 2'd1;
            end
            case ({do_wr, do_rd})
                2'b10:   count <= count + 3'd1;
                2'b01:   count <= count - 3'd1;
                default: count <= count;
            endcase
        end
    end

endmodule
