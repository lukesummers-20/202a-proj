Design the purely combinational module described by the following truth table (`x` = don't care).

| req[7] | req[6] | req[5] | req[4] | req[3] | req[2] | req[1] | req[0] | idx | valid |
|---|---|---|---|---|---|---|---|---|---|
| 1 | x | x | x | x | x | x | x | 7 | 1 |
| 0 | 1 | x | x | x | x | x | x | 6 | 1 |
| 0 | 0 | 1 | x | x | x | x | x | 5 | 1 |
| 0 | 0 | 0 | 1 | x | x | x | x | 4 | 1 |
| 0 | 0 | 0 | 0 | 1 | x | x | x | 3 | 1 |
| 0 | 0 | 0 | 0 | 0 | 1 | x | x | 2 | 1 |
| 0 | 0 | 0 | 0 | 0 | 0 | 1 | x | 1 | 1 |
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 1 |
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

There is no clock; `idx` and `valid` are functions of `req` only.
