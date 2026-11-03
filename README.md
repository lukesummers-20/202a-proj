# Does the *form* of a hardware spec change how well LLMs write RTL?

M202A Fall 2026 project. Same design, same testbench, four text-only spec formats
(prose / table / WaveDrom timing diagram / combined) × two HDL dialects (Verilog-2001 / SystemVerilog),
scored by open-source simulation. Project site: `docs/` (GitHub Pages).

## Pipeline

```
problems/<id>/spec_{prose,table,wave}.md ─┐
prompts/system.txt + dialect_{sv,v2001}.txt ─┼─► generate.py ─► runs/<run>/generations.jsonl  (every raw response)
problems/<id>/header.{sv,v} ──────────────┘          │
                                               extract.py   first fenced module…endmodule
                                                     │
                              lint.py   Gate 0 Slang parse/elaborate · Gate 1 Verilator --lint-only
                                        port check · construct counts · dialect compliance
                                                     │
                           simulate.py  Gate 2 compile (Icarus -g2012 | Verilator)
                                        Gate 3 cocotb testbench (identical for every cell), hard wall-clock kill
                                                     │
                            run_matrix.py ─► runs/<run>/results.jsonl (one row per generation)
                                                     │
                                score.py ─► pass@k per cell, bootstrap 95% CI over problems,
                                            failure classes, lint/compliance, greedy (T=0) samples
```

## Setup (macOS)

```bash
brew install icarus-verilog verilator
make setup          # python3.12 venv + cocotb, pyslang, pyyaml, openai, anthropic
make tools          # version sanity check
```

Tested with Icarus 13.0, Verilator 5.054, cocotb 2.1.0, pyslang 12.1, Python 3.12.
(Python 3.15 is the system default here but pyslang/cocotb wheels target ≤3.12/3.13, hence the pinned venv.)

## Running checkpoint 1

```bash
make check          # acceptance checklist: ref.sv + ref.v pass on Icarus AND Verilator,
                    #   every mutant fails, headers match problem.yaml, prompts build, ref lints clean
make mock           # 4 formats × 2 dialects × (5 + 1 T=0) samples with the mock provider, both sims, scored
make prompt         # read the exact prompt for one cell

# the real thing (needs ANTHROPIC_API_KEY or OPENAI_API_KEY; ~20–24 calls per problem per model)
make real PROVIDER=anthropic MODEL=<pinned-model-id> RUN=cp1
```

Individual scripts all have `--help`; the common ones:

```bash
python scripts/simulate.py --problem spi_slave_rx --design problems/spi_slave_rx/ref.sv --sim verilator
python scripts/lint.py     --problem spi_slave_rx --design cand.sv --dialect sv
python scripts/run_matrix.py --run-id X --problems spi_slave_rx --formats prose --dialects sv \
       --provider anthropic --model <id> --n 5 --greedy-extra --sim both --resume
python scripts/score.py --run-id X --by format dialect model --csv runs/X/summary.csv
```

## Layout

```
prompts/                   system prompt + dialect instructions (0-shot, fixed)
problems/<id>/
  problem.yaml             class, source, module, ports, formats, hidden requirements
  header.sv / header.v     module header the model must use verbatim
  spec_prose.md            F1
  spec_table.md            F2  interface + event + timing tables
  spec_wave.md             F3  WaveDrom JSON (text only); F4 "combined" = F1+F2+F3, built by generate.py
  ref.sv / ref.v           references (never shown to the model)
  tb/test_<id>.py          cocotb testbench, identical for every cell
  mutants/m*.sv            plausible wrong designs; every one must FAIL the testbench
scripts/                   generate · extract · lint · simulate · run_matrix · score · check_problem
runs/<run_id>/             generations.jsonl · prompts/ · designs/<cell>/*.sv · results.jsonl · summary.csv
runs/checks/<id>/summary.json   testbench-strength evidence from check_problem.py
```

Simulator work dirs (`runs/**/sim_*`) are git-ignored; everything needed to re-score is kept.


## Adding a problem

Copy `problems/spi_slave_rx/` to `problems/<new_id>/`, replace `problem.yaml`, headers, three specs,
`ref.sv` (+ `ref.v`), the testbench (rename to `tb/test_<new_id>.py`), write 3–6 mutants
(wrong edge, off-by-one, sticky flag, wrong reset, bit order, missing enable), then
`python scripts/check_problem.py <new_id> --sims icarus verilator` until it prints ALL AUTOMATED CHECKS PASS.
Also read each spec format alone and confirm the reference follows from it (format sufficiency is manual).

## Known limitations

- The testbench cannot detect a missing synchronizer in RTL simulation (a "no synchronizer" mutant passes; it was dropped).
- `classify()` is keyword-based on the first assertion message; hand-label a sample for the report.
- `dialect_compliant` is regex-based (a Slang-AST version is a later upgrade).
- `--resume` works per cell, not per sample.
