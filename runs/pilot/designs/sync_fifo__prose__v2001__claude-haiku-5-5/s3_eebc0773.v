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
    reg [1:0] wptr;
    reg [1:0] rptr;
    reg [2:0] count;

    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;

    always @(posedge clk) begin
        if (!rst_n) begin
            wptr    <= 2'd0;
            rptr    <= 2'd0;
            count   <= 3'd0;
            rd_data <= 8'd0;
            full    <= 1'b0;
            empty   <= 1'b1;
        end else begin
            if (do_wr) begin
                mem[wptr] <= wr_data;
                wptr      <= wptr + 2'd1;
            end

            if (do_rd) begin
                rd_data <= mem[rptr];
                rptr    <= rptr + 2'd1;
            end

            if (do_wr && !do_rd)
                count <= count + 3'd1;
            else if (do_rd && !do_wr)
                count <= count - 3'd1;

            full  <= (do_wr && !do_rd && (count == 3'd3)) || (full && !do_rd);
            empty <= (do_rd && !do_wr && (count == 3'd1)) || (empty && !do_wr);
        end
    end

endmodule
