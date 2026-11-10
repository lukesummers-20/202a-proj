Design a purely combinational 8-to-3 priority encoder used to pick which of eight interrupt request lines to service.

The input `req` is an 8-bit vector of request lines. Bit 7 has the highest priority and bit 0 the lowest. The output `idx` must be the 3-bit index of the highest-numbered bit of `req` that is 1; for example, if bits 5 and 2 are both set, `idx` is 5. The output `valid` must be 1 whenever at least one bit of `req` is 1. When `req` is all zeros, `valid` must be 0 and `idx` must be 0. There is no clock; outputs depend only on the current value of `req`.
