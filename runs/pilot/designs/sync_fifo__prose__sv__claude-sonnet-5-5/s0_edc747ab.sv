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
    logic [1:0] wr_ptr, rd_ptr;
    logic [2:0] count;
    logic       do_wr, do_rd;
    logic [2:0] next_count;

    always_comb begin
        do_wr = wr_en && !full;
        do_rd = rd_en && !empty;
        next_count = count;
        if (do_wr && !do_rd) next_count = count + 3'd1;
        else if (do_rd && !do_wr) next_count = count - 3'd1;
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
                wr_ptr <= wr_ptr + 2'd1;
            end
            if (do_rd) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= rd_ptr + 2'd1;
            end
            count <= next_count;
            full  <= (next_count == 3'd4);
            empty <= (next_count == 3'd0);
        end
    end

endmodule
