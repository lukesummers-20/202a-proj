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
    logic [2:0] n;
    logic [2:0] n_next;
    logic       wr_acc;
    logic       rd_acc;

    // Write is accepted whenever the FIFO is not full (a simultaneous read
    // on a full FIFO is still performed, so the write is dropped there).
    // Read is accepted whenever the FIFO is not empty (a simultaneous write
    // on an empty FIFO is still performed, so the read is dropped there).
    always_comb begin
        wr_acc = wr_en && !full;
        rd_acc = rd_en && !empty;
        n_next = n + {2'b00, wr_acc} - {2'b00, rd_acc};
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            n       <= 3'd0;
            wr_ptr  <= 2'd0;
            rd_ptr  <= 2'd0;
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
            n     <= n_next;
            full  <= (n_next == 3'd4);
            empty <= (n_next == 3'd0);
        end
    end

endmodule
