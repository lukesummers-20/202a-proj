#!/usr/bin/env python3
"""Acceptance checklist for a problem (checkpoint doc 3.2), run before any LLM call:

  1. ref.sv (and ref.v if present) passes the testbench on each requested simulator
  2. every mutant fails; reports how many distinct first-assertions (TB tests >1 property)
  3. (manual) each spec format is sufficient on its own  -> reminder printed, not automated
  4. header.sv / header.v have the same port names/order as problem.yaml
  5. every format's prompt builds (spec files exist), and the reference lints clean

  python scripts/check_problem.py spi_slave_rx [--sims icarus verilator]
Exit code 0 iff every automated check passes. Writes runs/checks/<problem>/summary.json."""
import argparse, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import lint as L  # noqa: E402
import simulate as S  # noqa: E402
from generate import build_prompt, DIALECTS  # noqa: E402


def header_ports(path):
    body = L.strip_comments(path.read_text())
    m = re.search(r"\((.*)\)\s*;", body, re.S)
    names = []
    for decl in (m.group(1) if m else "").split(","):
        w = re.findall(r"\w+", decl)
        if w:
            names.append(w[-1])
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("problem")
    ap.add_argument("--sims", nargs="+", default=["icarus"], choices=["icarus", "verilator"])
    a = ap.parse_args()
    pdir = ROOT / "problems" / a.problem
    prob = L.load_problem(a.problem)
    work = ROOT / "runs" / "checks" / a.problem
    ok = True
    summary = {"problem": a.problem, "sims": a.sims, "refs": {}, "mutants": {}}

    def report(passed, text):
        nonlocal ok
        ok &= bool(passed)
        print(f"  [{'OK' if passed else 'FAIL'}] {text}")

    print(f"== {a.problem} ({prob.get('class')}, {prob.get('source')}) ==")
    print("1. references pass")
    for ref in [p for p in (pdir / "ref.sv", pdir / "ref.v") if p.exists()]:
        for sim in a.sims:
            r = S.run_isolated(a.problem, ref, sim, workdir=work / f"{ref.name}_{sim}")
            summary["refs"][f"{ref.name}/{sim}"] = r["status"]
            report(r["status"] == "pass", f"{ref.name} on {sim}: {r['status']} {r['first_assert'] or ''}")

    print("2. mutants fail")
    muts = sorted((pdir / "mutants").glob("*.sv"))
    report(len(muts) >= 3, f"{len(muts)} mutants (target 3-6)")
    firsts = set()
    for m in muts:
        for sim in a.sims:
            r = S.run_isolated(a.problem, m, sim, workdir=work / f"{m.stem}_{sim}")
            summary["mutants"][f"{m.stem}/{sim}"] = {"status": r["status"], "first_assert": r["first_assert"]}
            firsts.add(r["first_assert"])
            report(r["status"] != "pass", f"{m.stem:22s} on {sim}: {r['status']:6s} | {r['first_assert']}")
    killed = sum(v["status"] != "pass" for v in summary["mutants"].values())
    summary["kill_rate"] = f"{killed}/{len(summary['mutants'])}"
    summary["distinct_first_asserts"] = len(firsts)
    print(f"  kill rate {summary['kill_rate']}, {len(firsts)} distinct first assertions")

    print("3. format sufficiency (manual): read each spec_*.md alone and confirm ref.sv follows from it")

    print("4. headers match problem.yaml")
    want = [p["name"] for p in prob["ports"]]
    for h in ("header.sv", "header.v"):
        got = header_ports(pdir / h)
        report(got == want, f"{h}: {got}" + ("" if got == want else f" != {want}"))

    print("5. prompts build and reference lints clean")
    for fmt in prob["formats"]:
        for dia in DIALECTS:
            try:
                build_prompt(a.problem, fmt, dia)
            except FileNotFoundError as e:
                report(False, f"prompt {fmt}/{dia}: {e}")
    report(True, f"prompts build for {prob['formats']} x {list(DIALECTS)}")
    for ref, dia in ((pdir / "ref.sv", "sv"), (pdir / "ref.v", "v2001")):
        if ref.exists():
            li = L.lint_all(ref, a.problem, dia)
            clean = li["slang_ok"] and li["verilator_ok"] and not li["verilator_warnings"] and li["ports_ok"]
            report(clean and li["dialect_compliant"],
                   f"{ref.name}: slang_ok={li['slang_ok']} verilator_ok={li['verilator_ok']} "
                   f"warnings={li['verilator_warnings']} dialect_compliant={li['dialect_compliant']}")

    work.mkdir(parents=True, exist_ok=True)
    (work / "summary.json").write_text(json.dumps(summary, indent=2))
    print(f"\n{'ALL AUTOMATED CHECKS PASS' if ok else 'SOME CHECKS FAILED'}  (summary: {work.relative_to(ROOT)}/summary.json)")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
