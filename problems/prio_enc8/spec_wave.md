Design the purely combinational module whose behavior is shown by the following timing diagram (WaveDrom notation). Outputs follow inputs with no clock; each column is a new input value.

```wavedrom
{ "signal": [
  { "name": "req[7:0]", "wave": "=========", "data": ["0x00","0x01","0x02","0x24","0x80","0xFF","0x30","0x08","0x00"] },
  { "name": "idx[2:0]", "wave": "=========", "data": ["0","0","1","5","7","7","5","3","0"] },
  { "name": "valid",    "wave": "01......0" }
],
  "head": { "text": "idx = index of the highest-numbered 1 bit in req; valid = (req != 0); idx = 0 when req = 0" }
}
```
