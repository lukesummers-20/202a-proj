module prio_enc8 (
    input  logic [7:0] req,    // interrupt request lines; bit 7 has the highest priority
    output logic [2:0] idx,    // index of the highest-priority asserted request
    output logic       valid   // 1 when at least one request is asserted
);

    always_comb begin
        idx   = 3'd0;
        valid = 1'b0;
        if (req[7]) begin
            idx = 3'd7; valid = 1'b1;
        end else if (req[6]) begin
            idx = 3'd6; valid = 1'b1;
        end else if (req[5]) begin
            idx = 3'd5; valid = 1'b1;
        end else if (req[4]) begin
            idx = 3'd4; valid = 1'b1;
        end else if (req[3]) begin
            idx = 3'd3; valid = 1'b1;
        end else if (req[2]) begin
            idx = 3'd2; valid = 1'b1;
        end else if (req[1]) begin
            idx = 3'd1; valid = 1'b1;
        end else if (req[0]) begin
            idx = 3'd0; valid = 1'b1;
        end
    end

endmodule
