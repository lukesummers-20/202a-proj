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

    // Status flags
    always_comb begin
        full  = (count == 3'd4);
        empty = (count == 3'd0);
    end

    // A write is accepted only when not full; a read only when not empty
    always_comb begin
        do_wr = wr_en && !full;
        do_rd = rd_en && !empty;
    end

    // Storage array
    always_ff @(posedge clk) begin
        if (do_wr)
            mem[wr_ptr] <= wr_data;
    end

    // Pointers, count, and registered read data
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr  <= 2'd0;
            rd_ptr  <= 2'd0;
            count   <= 3'd0;
            rd_data <= 8'h00;
        end else begin
            if (do_wr)
                wr_ptr <= wr_ptr + 2'd1;

            if (do_rd) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= rd_ptr + 2'd1;
            end

            case ({do_wr, do_rd})
                2'b10:   count <= count + 3'd1;
                2'b01:   count <= count - 3'd1;
                default: count <= count;
            endcase
        end
    end

endmodule
