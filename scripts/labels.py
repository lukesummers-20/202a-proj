#!/usr/bin/env python3
"""Hand-labelling worksheet for the failure taxonomy.

  python scripts/labels.py --run-id pilot            # create/refresh runs/pilot/labels.csv
  python scripts/labels.py --run-id pilot --summary  # tabulate manual_class by format (after labelling)

The worksheet has one row per failing generation, plus passing generations that ignored the dialect
instruction (pre-labelled dialect_ignored) or that pass on the primary simulator but not on the
other one (pre-labelled tool); both kinds still count as passes. Fill manual_class, root_cause
and notes by reading the design and the first assertion. Re-running keeps labels already entered."""
import argparse, csv, json, sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COLS = ["gen_id", "problem", "format", "dialect", "model", "sample", "greedy", "auto_class", "first_assert",
        "design_path", "manual_class", "root_cause", "notes"]
MANUAL = ["compile", "tool", "interface", "dialect_ignored", "latch_or_comb", "reset", "clocking_edge",
          "protocol_timing", "logic", "spec_misread", "other"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--summary", action="store_true")
    a = ap.parse_args()
    run = ROOT / "runs" / a.run_id
    path = run / "labels.csv"
    old = {r["gen_id"]: r for r in csv.DictReader(path.open())} if path.exists() else {}

    if a.summary:
        tab, bad = defaultdict(lambda: defaultdict(int)), []
        for r in old.values():
            mc = r["manual_class"].strip()
            if mc and mc not in MANUAL:
                bad.append((r["gen_id"], mc))
            tab[r["format"]][mc or "(unlabelled)"] += 1
        classes = sorted({c for t in tab.values() for c in t})
        print(f"{'manual_class':18s}" + "".join(f"{f:>10s}" for f in sorted(tab)) + f"{'total':>8s}")
        for c in classes:
            print(f"{c:18s}" + "".join(f"{tab[f][c]:10d}" for f in sorted(tab))
                  + f"{sum(tab[f][c] for f in tab):8d}")
        for g, mc in bad:
            print(f"warning: {g} has manual_class {mc!r}, not in the closed set", file=sys.stderr)
        return

    rows = [json.loads(l) for l in (run / "results.jsonl").open()]
    out = []
    for r in rows:
        ignored = r["sim_status"] == "pass" and r.get("dialect_compliant") is False
        toolgap = r["sim_status"] == "pass" and bool(r.get("sim_disagree"))   # passes on the primary sim only
        if r["sim_status"] == "pass" and not (ignored or toolgap):
            continue
        prev = old.get(r["gen_id"], {})
        out.append({"gen_id": r["gen_id"], "problem": r["problem"], "format": r["format"],
                    "dialect": r["dialect"], "model": r["model"], "sample": r["sample"],
                    "greedy": int(bool(r.get("greedy"))), "auto_class": r["failure_class"],
                    "first_assert": r.get("first_assert") or next(
                        (v["first_assert"] for v in (r.get("sim_by_tool") or {}).values() if v["first_assert"]), ""), "design_path": r["design_path"],
                    "manual_class": prev.get("manual_class") or ("dialect_ignored" if ignored else "tool" if toolgap else ""),
                    "root_cause": prev.get("root_cause", ""), "notes": prev.get("notes", "")})
    out.sort(key=lambda r: (r["problem"], r["format"], r["dialect"], r["model"], r["sample"]))
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLS)
        w.writeheader()
        w.writerows(out)
    done = sum(bool(r["manual_class"]) for r in out)
    print(f"wrote {path.relative_to(ROOT)}: {len(out)} rows to label ({done} already labelled) "
          f"out of {len(rows)} generations")
    print("manual_class must be one of: " + ", ".join(MANUAL))


if __name__ == "__main__":
    main()
