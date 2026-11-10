module prio_enc8 (
    input  wire [7:0] req,    // interrupt request lines; bit 7 has the highest priority
    output reg  [2:0] idx,    // index of the highest-priority asserted request
    output reg        valid   // 1 when at least one request is asserted
);
