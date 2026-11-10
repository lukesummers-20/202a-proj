// MUTANT m1_lowest_priority: lowest set bit wins
module prio_enc8 (
    input  logic [7:0] req,
    output logic [2:0] idx,
    output logic       valid
);
    always_comb begin
        valid = |req;
        idx   = 3'd0;
        for (int i = 7; i >= 0; i--)
            if (req[i]) idx = i[2:0];   // last assignment wins -> highest index
    end
endmodule
