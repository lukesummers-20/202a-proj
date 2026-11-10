// Verilog-2001 reference (never shown to the model). Same behaviour as ref.sv.
module sync_fifo (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire  [7:0] wr_data,
    input  wire        rd_en,
    output reg   [7:0] rd_data,
    output reg         full,
    output reg         empty
);
    reg   [7:0] mem [0:3];
    reg   [1:0] wptr, rptr;
    reg   [2:0] count;

    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;

    always @(posedge clk) begin
        if (!rst_n) begin
            wptr <= 2'd0; rptr <= 2'd0; count <= 3'd0;
            rd_data <= 8'd0; full <= 1'b0; empty <= 1'b1;
        end else begin
            if (do_wr) begin
                mem[wptr] <= wr_data;
                wptr <= wptr + 2'd1;
            end
            if (do_rd) begin
                rd_data <= mem[rptr];
                rptr <= rptr + 2'd1;
            end
            case ({do_wr, do_rd})
                2'b10: begin count <= count + 3'd1; full <= (count == 3'd3); empty <= 1'b0; end
                2'b01: begin count <= count - 3'd1; full <= 1'b0; empty <= (count == 3'd1); end
                default: ;   // 00 or 11: count unchanged
            endcase
        end
    end
endmodule
