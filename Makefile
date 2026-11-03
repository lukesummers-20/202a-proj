# Checkpoint-1 entry points. Run from the repo root.
#   make setup     venv + python deps (simulators: brew install icarus-verilog verilator)
#   make check     acceptance checklist for every problem (ref passes, mutants fail, headers, lint)
#   make mock      whole matrix with the mock provider (zero API cost) + scoring
#   make prompt    print one assembled prompt
#   make real MODEL=<id> PROVIDER=anthropic|openai   one real-model run over all formats (sv)
PY       ?= .venv/bin/python
PROBLEMS ?= $(notdir $(wildcard problems/*))
SIMS     ?= icarus verilator
RUN      ?= cp1
PROVIDER ?= anthropic
MODEL    ?=
N        ?= 5

.PHONY: setup tools check mock prompt real score clean

setup:
	python3.12 -m venv .venv
	.venv/bin/pip install -r requirements.txt

tools:
	@iverilog -V 2>/dev/null | head -1 ; verilator --version ; \
	$(PY) -c "import cocotb, pyslang; print('cocotb', cocotb.__version__)"

check:
	@for p in $(PROBLEMS); do $(PY) scripts/check_problem.py $$p --sims $(SIMS) || exit 1; done

mock:
	rm -rf runs/cp1_mock
	$(PY) scripts/run_matrix.py --run-id cp1_mock --problems $(PROBLEMS) \
	    --formats prose table wave combined --dialects sv v2001 \
	    --provider mock --model mock-mixed --n 5 --greedy-extra --sim both
	$(PY) scripts/score.py --run-id cp1_mock --by format dialect --csv runs/cp1_mock/summary.csv

prompt:
	$(PY) scripts/generate.py --problem spi_slave_rx --format table --dialect sv --print-prompt

real:
	@test -n "$(MODEL)" || (echo "set MODEL=<pinned model id>"; exit 1)
	$(PY) scripts/run_matrix.py --run-id $(RUN) --problems $(PROBLEMS) \
	    --formats prose table wave combined --dialects sv \
	    --provider $(PROVIDER) --model $(MODEL) --n $(N) --temperature 0.8 --greedy-extra \
	    --sim both --resume
	$(MAKE) score RUN=$(RUN)

score:
	$(PY) scripts/score.py --run-id $(RUN) --by format dialect model --csv runs/$(RUN)/summary.csv

clean:
	find runs -type d \( -name 'sim_*' -o -name sim_build \) -prune -exec rm -rf {} +
	rm -rf runs/checks/*/*/
