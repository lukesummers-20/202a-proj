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
    reg [2:0] count_next;

    wire wr_acc = wr_en && !full;
    wire rd_acc = rd_en && !empty;

    always @(*) begin
        case ({wr_acc, rd_acc})
            2'b10:   count_next = count + 3'd1;
            2'b01:   count_next = count - 3'd1;
            default: count_next = count;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            count   <= 3'd0;
            wptr    <= 2'd0;
            rptr    <= 2'd0;
            rd_data <= 8'd0;
            full    <= 1'b0;
            empty   <= 1'b1;
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
