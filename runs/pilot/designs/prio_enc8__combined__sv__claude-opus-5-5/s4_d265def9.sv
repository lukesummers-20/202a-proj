module prio_enc8 (
    input  logic [7:0] req,    // interrupt request lines; bit 7 has the highest priority
    output logic [2:0] idx,    // index of the highest-priority asserted request
    output logic       valid   // 1 when at least one request is asserted
);

    always_comb begin
        idx   = 3'd0;
        valid = |req;
        casez (req)
            8'b1???????: idx = 3'd7;
            8'b01??????: idx = 3'd6;
            8'b001?????: idx = 3'd5;
            8'b0001????: idx = 3'd4;
            8'b00001???: idx = 3'd3;
            8'b000001??: idx = 3'd2;
            8'b0000001?: idx = 3'd1;
            default:     idx = 3'd0;
        endcase
    end

endmodule
