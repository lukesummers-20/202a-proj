Design the module whose behavior is shown by the following timing diagrams (WaveDrom notation). Everything is synchronous to the rising edge of `clk`; each column is one `clk` cycle, inputs are sampled at the rising edge that ends the column, and outputs change just after that edge.

**Diagram 1 — fill to full, a write while full is ignored, then drain; a read while empty is ignored**

```wavedrom
{ "signal": [
  { "name": "clk",     "wave": "p............" },
  { "name": "rst_n",   "wave": "01..........." },
  { "name": "wr_en",   "wave": "0.1....0....." },
  { "name": "wr_data", "wave": "x.=====x.....", "data": ["A","B","C","D","E"] },
  { "name": "rd_en",   "wave": "0......1....0" },
  {},
  { "name": "rd_data", "wave": "=.......====.", "data": ["00","A","B","C","D"] },
  { "name": "empty",   "wave": "1..0.......1." },
  { "name": "full",    "wave": "0.....1.0...." }
],
  "head": { "text": "item E is ignored (full); reads return A,B,C,D in order; the 5th read is ignored (empty) and rd_data holds D" }
}
```

**Diagram 2 — simultaneous read and write keeps the count; read while empty is ignored**

```wavedrom
{ "signal": [
  { "name": "clk",     "wave": "p........" },
  { "name": "rst_n",   "wave": "01......." },
  { "name": "wr_en",   "wave": "0.1010..." },
  { "name": "wr_data", "wave": "x.=x=x...", "data": ["P","Q"] },
  { "name": "rd_en",   "wave": "0.101010." },
  {},
  { "name": "rd_data", "wave": "=....=.=.", "data": ["00","P","Q"] },
  { "name": "empty",   "wave": "1..0...1." },
  { "name": "full",    "wave": "0........" }
],
  "head": { "text": "cycle 2: read ignored (empty), write P accepted; cycle 4: write Q and read P in the same cycle, count stays 1; cycle 6: read Q" }
}
```

**Diagram 3 — read and write requested together while full: the read is accepted, the write is ignored**

```wavedrom
{ "signal": [
  { "name": "clk",     "wave": "p.........." },
  { "name": "rst_n",   "wave": "01........." },
  { "name": "wr_en",   "wave": "0.1....0..." },
  { "name": "wr_data", "wave": "x.=====x...", "data": ["W","X","Y","Z","V"] },
  { "name": "rd_en",   "wave": "0.....1...0" },
  {},
  { "name": "rd_data", "wave": "=......====", "data": ["00","W","X","Y","Z"] },
  { "name": "empty",   "wave": "1..0......1" },
  { "name": "full",    "wave": "0.....10..." }
],
  "head": { "text": "cycle 6: full, so item V is ignored while W is read; the FIFO then drains X,Y,Z and is empty (V was never stored)" }
}
```
