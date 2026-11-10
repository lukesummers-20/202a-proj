#!/usr/bin/env python3
"""generate -> extract -> lint -> simulate -> runs/<run_id>/results.jsonl, for any slice of the matrix.

  python scripts/run_matrix.py --run-id cp1_mock --problems spi_slave_rx --formats prose table wave combined \
      --dialects sv v2001 --provider mock --model mock-mixed --n 5
  python scripts/run_matrix.py --run-id pilot --problems spi_slave_rx --formats prose wave \
      --dialects sv --provider anthropic --model <MODEL_ID> --n 5 --temperature 0.8 --greedy-extra

--sim both : run Icarus AND Verilator. The primary result is Verilator for sv and Icarus for v2001
             (proposal 3.4), and it alone decides pass/fail. A row where the two disagree has
             sim_disagree=true; its failure_class is "tool" only if the primary simulator is the one failing.
--resume   : skips cells (problem, format, dialect, model) already in results.jsonl.
"""
import argparse, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from generate import generate, FORMATS, DIALECTS  # noqa: E402
from extract import extract  # noqa: E402
import lint as L  # noqa: E402
import simulate as S  # noqa: E402
import yaml  # noqa: E402

PRIMARY_SIM = {"sv": "verilator", "v2001": "icarus"}


def classify(row):
    """Coarse failure class for the taxonomy table; refine by hand on a sample."""
    if row["extract_reason"] in ("no_code_found", "empty_response"):
        return "no_code"
    if not row["ports_ok"]:
        return "interface"
    st = row["sim_status"]
    if st == "pass":
        return "pass"          # primary simulator decides; a disagreement is kept in row["sim_disagree"]
    if row.get("sim_disagree"):
        return "tool"          # fails on the primary simulator only
    if st in ("compile_error", "timeout", "tool_error"):
        return {"compile_error": "compile", "timeout": "timeout", "tool_error": "tool"}[st]
    msg = (row.get("first_assert") or "").lower()
    if "reset" in msg or msg.startswith("t1"):
        return "functional_reset"
    if "latency" in msg or "never asserted" in msg or "wider" in msg:
        return "functional_timing"
    return "functional_logic"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--problems", nargs="+", required=True)
    ap.add_argument("--formats", nargs="+", default=FORMATS, choices=FORMATS)
    ap.add_argument("--dialects", nargs="+", default=["sv"], choices=list(DIALECTS))
    ap.add_argument("--provider", default="mock", choices=["mock", "openai", "anthropic"])
    ap.add_argument("--model", default="mock-mixed")
    ap.add_argument("--n", type=int, default=5)
    ap.add_argument("--temperature", type=float, default=0.8)
    ap.add_argument("--max-tokens", type=int, default=4096)
    ap.add_argument("--greedy-extra", action="store_true", help="one extra T=0 sample per cell")
    ap.add_argument("--sim", default="icarus", choices=["icarus", "verilator", "both"])
    ap.add_argument("--sim-timeout", type=int, default=120, help="wall-clock seconds per simulation")
    ap.add_argument("--resume", action="store_true")
    a = ap.parse_args()

    run_dir = ROOT / "runs" / a.run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    results = run_dir / "results.jsonl"
    done = set()
    if a.resume and results.exists():
        for line in results.open():
            r = json.loads(line)
            done.add((r["problem"], r["format"], r["dialect"], r["model"]))

    for pid in a.problems:
        prob = yaml.safe_load((ROOT / "problems" / pid / "problem.yaml").read_text())
        for fmt in a.formats:
            if fmt not in prob["formats"]:
                continue
            for dia in a.dialects:
                if (pid, fmt, dia, a.model) in done:
                    continue
                sims = ["icarus", "verilator"] if a.sim == "both" else [a.sim]
                primary = PRIMARY_SIM[dia] if a.sim == "both" else a.sim
                print(f"[{a.run_id}] {pid} {fmt} {dia} {a.model} x{a.n}{'+T0' if a.greedy_extra else ''}",
                      flush=True)
                gens = generate(pid, fmt, dia, a.provider, a.model, a.n, a.temperature, a.max_tokens,
                                a.run_id, greedy_extra=a.greedy_extra)
                cell = run_dir / "designs" / f"{pid}__{fmt}__{dia}__{a.model}".replace("/", "_")
                cell.mkdir(parents=True, exist_ok=True)
                for g in gens:
                    code, why = extract(g["response"])
                    dpath = cell / f"s{g['sample']}_{g['gen_id']}{DIALECTS[dia][3]}"
                    row = {k: g.get(k) for k in ("gen_id", "run_id", "problem", "format", "dialect", "provider",
                                                 "model", "model_version", "sample", "seed", "greedy",
                                                 "temperature", "max_tokens", "prompt_hash", "usage",
                                                 "stop_reason", "latency_s", "timestamp")}
                    row.update({"class": prob.get("class"), "source": prob.get("source"),
                                "design_path": str(dpath.relative_to(ROOT)), "extract_reason": why})
                    if code is None:
                        row.update({"ports_ok": False, "ports_msg": "no code", "sim_status": "no_code",
                                    "first_assert": None, "lint": None, "constructs": None,
                                    "dialect_compliant": None})
                    else:
                        dpath.write_text(code)
                        lint = L.lint_all(dpath, pid, dia)
                        row.update({"ports_ok": lint.pop("ports_ok"), "ports_msg": lint.pop("ports_msg"),
                                    "constructs": lint.pop("constructs"),
                                    "dialect_compliant": lint.pop("dialect_compliant"), "lint": lint})
                        by_sim = {s: S.run_isolated(pid, dpath, s, workdir=cell / f"sim_s{g['sample']}_{s}",
                                                    timeout=a.sim_timeout) for s in sims}
                        p = by_sim[primary]
                        row.update({"sim": primary, "sim_status": p["status"], "first_assert": p["first_assert"],
                                    "sim_wall_s": p["wall_s"]})
                        if len(sims) > 1:
                            row["sim_by_tool"] = {s: {"status": r["status"], "first_assert": r["first_assert"]}
                                                  for s, r in by_sim.items()}
                            row["sim_disagree"] = len({(r["status"] == "pass") for r in by_sim.values()}) > 1
                    row["failure_class"] = classify(row)
                    with results.open("a") as f:
                        f.write(json.dumps(row) + "\n")
                    tag = f"s{g['sample']}{'(T0)' if g.get('greedy') else ''}"
                    print(f"   {tag:7s} {row['failure_class']:18s} {row.get('first_assert') or ''}"[:120],
                          flush=True)
    print(f"done -> {results.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
