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
    logic [1:0] wptr;
    logic [1:0] rptr;
    logic [2:0] count;
    logic [2:0] count_n;
    logic       wr_acc;
    logic       rd_acc;

    always_comb begin
        wr_acc  = wr_en && !full;
        rd_acc  = rd_en && !empty;
        count_n = count;
        if (wr_acc && !rd_acc)
            count_n = count + 3'd1;
        else if (rd_acc && !wr_acc)
            count_n = count - 3'd1;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wptr    <= 2'd0;
            rptr    <= 2'd0;
            count   <= 3'd0;
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
            count <= count_n;
            full  <= (count_n == 3'd4);
            empty <= (count_n == 3'd0);
        end
    end

endmodule
