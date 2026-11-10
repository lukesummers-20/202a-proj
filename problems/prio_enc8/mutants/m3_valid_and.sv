// MUTANT m3_valid_and: valid is the AND of the requests
module prio_enc8 (
    input  logic [7:0] req,
    output logic [2:0] idx,
    output logic       valid
);
    always_comb begin
        valid = &req;
        idx   = 3'd0;
        for (int i = 0; i < 8; i++)
            if (req[i]) idx = i[2:0];   // last assignment wins -> highest index
    end
endmodule
