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

    reg [7:0] mem [0:3];
    reg [1:0] wptr;
    reg [1:0] rptr;
    reg [2:0] count;

    wire wr_acc = wr_en & ~full;
    wire rd_acc = rd_en & ~empty;

    reg [2:0] count_next;
    always @(*) begin
        count_next = count;
        if (wr_acc & ~rd_acc)
            count_next = count + 3'd1;
        else if (rd_acc & ~wr_acc)
            count_next = count - 3'd1;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            wptr    <= 2'd0;
            rptr    <= 2'd0;
            count   <= 3'd0;
            rd_data <= 8'd0;
            empty   <= 1'b1;
            full    <= 1'b0;
        end else begin
            if (wr_acc) begin
                mem[wptr] <= wr_data;
                wptr      <= wptr + 2'd1;
            end
            if (rd_acc) begin
                rd_data <= mem[rptr];
                rptr    <= rptr + 2'd1;
            end
            count <= count_next;
            full  <= (count_next == 3'd4);
            empty <= (count_next == 3'd0);
        end
    end

endmodule
