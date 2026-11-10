// Verilog-2001 reference (never shown to the model). Same behaviour as ref.sv.
module prio_enc8 (
    input  wire [7:0] req,
    output reg  [2:0] idx,
    output reg        valid
);
    integer i;
    always @(*) begin
        valid = |req;
        idx   = 3'd0;
        for (i = 0; i < 8; i = i + 1)
            if (req[i]) idx = i[2:0];   // last assignment wins -> highest index
    end
endmodule
