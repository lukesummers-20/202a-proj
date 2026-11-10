module prio_enc8 (
    input  logic [7:0] req,    // interrupt request lines; bit 7 has the highest priority
    output logic [2:0] idx,    // index of the highest-priority asserted request
    output logic       valid   // 1 when at least one request is asserted
);

    always_comb begin
        valid = |req;
        if (req[7])      idx = 3'd7;
        else if (req[6]) idx = 3'd6;
        else if (req[5]) idx = 3'd5;
        else if (req[4]) idx = 3'd4;
        else if (req[3]) idx = 3'd3;
        else if (req[2]) idx = 3'd2;
        else if (req[1]) idx = 3'd1;
        else             idx = 3'd0;
    end

endmodule
