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
    logic [1:0] wr_ptr;
    logic [1:0] rd_ptr;
    logic [2:0] count;
    logic [2:0] count_next;
    logic       do_wr;
    logic       do_rd;

    // Accepted operations per the operation table
    always_comb begin
        do_wr = wr_en && (count != 3'd4);
        do_rd = rd_en && (count != 3'd0);

        case ({do_wr, do_rd})
            2'b10:   count_next = count + 3'd1;
            2'b01:   count_next = count - 3'd1;
            default: count_next = count;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr  <= 2'd0;
            rd_ptr  <= 2'd0;
            count   <= 3'd0;
            rd_data <= 8'd0;
            full    <= 1'b0;
            empty   <= 1'b1;
        end else begin
            if (do_wr) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 2'd1;
            end
            if (do_rd) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= rd_ptr + 2'd1;
            end
            count <= count_next;
            full  <= (count_next == 3'd4);
            empty <= (count_next == 3'd0);
        end
    end

endmodule
