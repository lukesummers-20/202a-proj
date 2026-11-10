module prio_enc8 (
    input  logic [7:0] req,    // interrupt request lines; bit 7 has the highest priority
    output logic [2:0] idx,    // index of the highest-priority asserted request
    output logic       valid   // 1 when at least one request is asserted
);
    always_comb begin
        idx   = 3'd0;
        valid = |req;
        for (int i = 0; i < 8; i++) begin
            if (req[i]) idx = i[2:0];
        end
    end
endmodule
