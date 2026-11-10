// MUTANT m4_off_by_one: idx is one too high
module prio_enc8 (
    input  logic [7:0] req,
    output logic [2:0] idx,
    output logic       valid
);
    always_comb begin
        valid = |req;
        idx   = 3'd0;
        for (int i = 0; i < 8; i++)
            if (req[i]) idx = i[2:0] + 3'd1;   // last assignment wins -> highest index
    end
endmodule
