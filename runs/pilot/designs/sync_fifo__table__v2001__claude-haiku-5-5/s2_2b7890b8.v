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

    // Storage and pointers
    reg [7:0] mem [0:3];
    reg [1:0] wr_ptr;
    reg [1:0] rd_ptr;
    reg [2:0] count;

    // Accepted operations (combinational qualifiers)
    wire wr_acc = wr_en & ~full;
    wire rd_acc = rd_en & ~empty;

    // Next-state values
    reg [2:0] count_nxt;

    always @(*) begin
        case ({wr_acc, rd_acc})
            2'b10:   count_nxt = count + 3'd1;
            2'b01:   count_nxt = count - 3'd1;
            default: count_nxt = count;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr  <= 2'd0;
            rd_ptr  <= 2'd0;
            count   <= 3'd0;
            rd_data <= 8'd0;
            full    <= 1'b0;
            empty   <= 1'b1;
        end else begin
            if (wr_acc) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 2'd1;
            end
            if (rd_acc) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= rd_ptr + 2'd1;
            end
            count <= count_nxt;
            full  <= (count_nxt == 3'd4);
            empty <= (count_nxt == 3'd0);
        end
    end

endmodule
