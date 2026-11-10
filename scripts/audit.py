#!/usr/bin/env python3
"""Testbench-strength audit across problems: every reference must pass and every mutant must fail,
on every requested simulator. Prints the table for the report and writes runs/audit/audit.{json,md}.
(check_problem.py is the full per-problem acceptance checklist; this is the cross-problem summary.)

  python scripts/audit.py [--problems spi_slave_rx prio_enc8 sync_fifo] [--sims icarus verilator]
Exit code 0 iff every problem is OK."""
import argparse, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import simulate as S  # noqa: E402
from lint import load_problem  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--problems", nargs="*", default=None)
    ap.add_argument("--sims", nargs="+", default=["icarus", "verilator"], choices=["icarus", "verilator"])
    a = ap.parse_args()
    probs = a.problems or sorted(p.name for p in (ROOT / "problems").iterdir() if (p / "problem.yaml").exists())
    out_dir = ROOT / "runs" / "audit"
    rows, detail = [], {}
    for pid in probs:
        pdir = ROOT / "problems" / pid
        work = out_dir / pid
        refs = [p for p in (pdir / "ref.sv", pdir / "ref.v") if p.exists()]
        muts = sorted((pdir / "mutants").glob("*.sv"))
        ref_runs = {f"{r.name}/{s}": S.run_isolated(pid, r, s, workdir=work / f"sim_{r.name}_{s}")
                    for r in refs for s in a.sims}
        mut_runs = {f"{m.stem}/{s}": S.run_isolated(pid, m, s, workdir=work / f"sim_{m.stem}_{s}")
                    for m in muts for s in a.sims}
        ref_pass = sum(r["status"] == "pass" for r in ref_runs.values())
        killed = [m for m in muts if all(mut_runs[f"{m.stem}/{s}"]["status"] != "pass" for s in a.sims)]
        firsts = {(r["first_assert"] or r["status"]) for r in mut_runs.values() if r["status"] != "pass"}
        # simulators agree when a design passes on both or fails on both
        agree = sum(len({runs[f"{d}/{s}"]["status"] == "pass" for s in a.sims}) == 1
                    for runs, names in ((ref_runs, [r.name for r in refs]), (mut_runs, [m.stem for m in muts]))
                    for d in names)
        ok = ref_pass == len(ref_runs) and len(killed) == len(muts) and len(muts) >= 3
        rows.append({"problem": pid, "class": load_problem(pid).get("class"),
                     "refs_pass": f"{ref_pass}/{len(ref_runs)}", "mutants_killed": f"{len(killed)}/{len(muts)}",
                     "distinct_first_asserts": len(firsts), "sim_agreement": f"{agree}/{len(refs) + len(muts)}",
                     "status": "OK" if ok else "FIX"})
        detail[pid] = {"refs": {k: v["status"] for k, v in ref_runs.items()},
                       "mutants": {k: {"status": v["status"], "first_assert": v["first_assert"]}
                                   for k, v in mut_runs.items()}}

    cols = [("problem", "problem"), ("class", "class"), ("refs_pass", "ref runs pass"),
            ("mutants_killed", "mutants killed"), ("distinct_first_asserts", "distinct first asserts"),
            ("sim_agreement", "sims agree"), ("status", "status")]
    width = [max(len(h), *(len(str(r[k])) for r in rows)) for k, h in cols]
    print("  ".join(h.ljust(w) for (_, h), w in zip(cols, width)))
    for r in rows:
        print("  ".join(str(r[k]).ljust(w) for (k, _), w in zip(cols, width)))
    tot_k = sum(int(r["mutants_killed"].split("/")[0]) for r in rows)
    tot_m = sum(int(r["mutants_killed"].split("/")[1]) for r in rows)
    n_ok = sum(r["status"] == "OK" for r in rows)
    print(f"\n{n_ok}/{len(rows)} problems OK, {tot_k}/{tot_m} mutants killed on {' + '.join(a.sims)}")

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "audit.json").write_text(json.dumps({"sims": a.sims, "rows": rows, "detail": detail}, indent=1))
    md = ["| " + " | ".join(h for _, h in cols) + " |", "|" + "---|" * len(cols)]
    md += ["| " + " | ".join(str(r[k]) for k, _ in cols) + " |" for r in rows]
    (out_dir / "audit.md").write_text("\n".join(md) + f"\n\nSimulators: {', '.join(a.sims)}. "
                                      f"{tot_k}/{tot_m} mutants killed.\n")
    sys.exit(0 if n_ok == len(rows) else 1)


if __name__ == "__main__":
    main()
